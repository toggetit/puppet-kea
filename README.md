# kea

[![CI](https://github.com/peelman/puppet-kea/actions/workflows/ci.yml/badge.svg)](https://github.com/peelman/puppet-kea/actions/workflows/ci.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/peelman/kea?labelColor=667&color=369)](https://forge.puppetlabs.com/peelman/kea)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/peelman/kea.svg?labelColor=667&color=%23369)](https://forge.puppetlabs.com/peelman/kea)
[![License](https://img.shields.io/github/license/peelman/puppet-kea.svg?labelColor=667&color=369)](https://github.com/peelman/puppet-kea/blob/main/LICENSE)

## Table of Contents

1. [Description](#description)
2. [Setup](#setup)
3. [Usage](#usage)
   - [High Availability](#high-availability-ha)
4. [Reference](#reference)
5. [Examples](#examples)

## Description

This module installs and configures ISC Kea DHCP server (version 3.x) from the official
ISC Cloudsmith repositories. It supports:

- **DHCPv4** server (`kea-dhcp4`)
- **DHCPv6** server (`kea-dhcp6`)
- **DHCP-DDNS** server (`kea-dhcp-ddns`)

The module is designed for Debian and Ubuntu systems and uses Hiera-driven configuration
for maximum flexibility.

## Setup

### Requirements

- Puppet 7.x or 8.x
- `puppetlabs-stdlib` module
- `puppetlabs-apt` module

### Beginning with kea

Include the module and enable the components you need via Hiera:

```puppet
include kea
```

```yaml
# In your Hiera data
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
```

## Usage

### Basic DHCPv4 Server

```yaml
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  valid_lifetime: 4000
  renew_timer: 1000
  rebind_timer: 2000
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
      option-data:
        - name: 'routers'
          data: '192.168.1.1'
        - name: 'domain-name-servers'
          data: '8.8.8.8, 8.8.4.4'
        - name: 'domain-name'
          data: 'example.com'
```

### DHCPv4 with Host Reservations

```yaml
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
      reservations:
        - hw-address: '00:11:22:33:44:55'
          ip-address: '192.168.1.10'
          hostname: 'server1'
        - hw-address: '00:11:22:33:44:56'
          ip-address: '192.168.1.11'
          hostname: 'server2'
```

### DHCPv4 with MySQL Backend

```yaml
kea::mysql_backend: true
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  lease_database:
    type: 'mysql'
    name: 'kea'
    host: 'localhost'
    port: 3306
    user: 'kea'
    password: 'secret'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

### DHCPv6 Server

```yaml
kea::dhcp6:
  enable: true
  interfaces:
    - 'eth0'
  preferred_lifetime: 3000
  valid_lifetime: 4000
  subnets:
    - id: 1
      subnet: '2001:db8:1::/64'
      pools:
        - pool: '2001:db8:1::100 - 2001:db8:1::200'
      option-data:
        - name: 'dns-servers'
          data: '2001:db8:1::1'
```

### DHCP with Dynamic DNS Updates

```yaml
kea::ddns:
  enable: true
  ip_address: '127.0.0.1'
  port: 53001
  forward_ddns:
    ddns_domains:
      - name: 'example.com.'
        dns_servers:
          - ip_address: '192.168.1.1'
            port: 53

kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  ddns_send_updates: true
  ddns_qualifying_suffix: 'example.com'
  ddns_replace_client_name: 'when-not-present'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

### Using Hooks Libraries

```yaml
kea::hooks_package: true
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  hooks_libraries:
    - library: '/usr/lib/x86_64-linux-gnu/kea/hooks/libdhcp_lease_cmds.so'
    - library: '/usr/lib/x86_64-linux-gnu/kea/hooks/libdhcp_stat_cmds.so'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

### High Availability (HA)

Kea supports high availability configurations with automatic failover. This module provides
structured HA support with validated parameters. The module automatically configures the
HA hook library and merges it with any manually specified hooks.

**HA Modes:**
- `hot-standby`: Active/passive failover. One primary handles all traffic; standby takes over on failure.
- `load-balancing`: Active/active. Both servers handle traffic, with automatic failover.
- `passive-backup`: Simple backup without state synchronization (Kea 2.4+).

#### Hot-Standby Configuration

```yaml
# On server1.example.com (primary)
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  ha:
    mode: 'hot-standby'
    this_server: 'server1'  # Optional: auto-detected from $facts['networking']['fqdn']
    heartbeat_delay: 10000
    max_response_delay: 60000
    max_unacked_clients: 5
    peers:
      - name: 'server1'
        url: 'http://192.168.1.10:8000/'
        role: 'primary'
      - name: 'server2'
        url: 'http://192.168.1.11:8000/'
        role: 'standby'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

```yaml
# On server2.example.com (standby)
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  ha:
    mode: 'hot-standby'
    this_server: 'server2'
    heartbeat_delay: 10000
    max_response_delay: 60000
    max_unacked_clients: 5
    peers:
      - name: 'server1'
        url: 'http://192.168.1.10:8000/'
        role: 'primary'
      - name: 'server2'
        url: 'http://192.168.1.11:8000/'
        role: 'standby'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

#### Load-Balancing Configuration

In load-balancing mode, both servers actively serve DHCP requests. The servers coordinate
lease assignments to prevent conflicts.

```yaml
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  ha:
    mode: 'load-balancing'
    heartbeat_delay: 10000
    max_response_delay: 60000
    max_unacked_clients: 5
    peers:
      - name: 'server1'
        url: 'http://192.168.1.10:8000/'
        role: 'primary'
      - name: 'server2'
        url: 'http://192.168.1.11:8000/'
        role: 'secondary'
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

**Note:** In load-balancing mode, use `primary` and `secondary` roles (not `standby`).

#### HA Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mode` | String | - | HA mode: `hot-standby`, `load-balancing`, `passive-backup` |
| `this_server` | String | auto | Name of this server (must match a peer name) |
| `peers` | Array | - | Array of peer configurations |
| `heartbeat_delay` | Integer | 10000 | Heartbeat interval in milliseconds |
| `max_response_delay` | Integer | 60000 | Max time to wait for partner response (ms) |
| `max_unacked_clients` | Integer | 5 | Failed client queries before failover |
| `max_ack_delay` | Integer | - | Max delay for client acknowledgments (ms) |
| `sync_timeout` | Integer | - | Lease database sync timeout (ms) |
| `sync_page_limit` | Integer | - | Max leases per sync page |
| `delayed_updates_limit` | Integer | - | Max queued lease updates |
| `send_lease_updates` | Boolean | - | Enable lease update notifications |
| `sync_leases` | Boolean | - | Enable lease synchronization |
| `wait_backup_ack` | Boolean | - | Wait for backup server acknowledgment |
| `multi_threading` | Hash | - | Multi-threading configuration |
| `state_machine` | Hash | - | State machine timing configuration |

Each peer in the `peers` array:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | Yes | Unique peer name (use FQDN for auto-detection) |
| `url` | String | Yes | HTTP URL for HA communication |
| `role` | String | Yes | Peer role: `primary`, `secondary`, `standby`, `backup` |
| `auto_failover` | Boolean | No | Enable automatic failover for this peer (default: true) |

#### Automatic Server Detection

If `this_server` is not specified, the module automatically detects it by matching
`$facts['networking']['fqdn']` against the peer names. This allows using the same Hiera
configuration on both HA nodes:

```yaml
# In common.yaml - same config works on both servers
kea::dhcp4:
  enable: true
  ha:
    mode: 'hot-standby'
    # this_server is auto-detected from FQDN
    peers:
      - name: 'dhcp1.example.com'
        url: 'http://192.168.1.10:8000/'
        role: 'primary'
      - name: 'dhcp2.example.com'
        url: 'http://192.168.1.11:8000/'
        role: 'standby'
```

### Client Classes

```yaml
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  client_classes:
    - name: 'voip-phones'
      test: "substring(option[60].hex,0,6) == 'Polycom'"
      option-data:
        - name: 'tftp-server-name'
          data: 'tftp.example.com'
    - name: 'printers'
      test: "substring(option[60].hex,0,2) == 'HP'"
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

### Custom Logging Configuration

```yaml
kea::dhcp4:
  enable: true
  interfaces:
    - 'eth0'
  logging:
    severity: 'DEBUG'
    debuglevel: 50
    output: '/var/log/kea/kea-dhcp4.log'
    maxsize: 20971520  # 20MB
    maxver: 10
  subnets:
    - id: 1
      subnet: '192.168.1.0/24'
      pools:
        - pool: '192.168.1.100 - 192.168.1.200'
```

### Modular Subnet Configuration via Hiera

Instead of defining all subnets inline within `kea::dhcp4::subnets`, you can define them
separately in Hiera using the `kea::dhcp4::subnets` hash. This allows subnets to be
defined at any level of your Hiera hierarchy and merged together using deep merge.

This is particularly useful when you have many subnets and want to organize them
across multiple Hiera files or hierarchy levels.

```yaml
# In common.yaml - define shared subnets
kea::dhcp4::subnets:
  management:
    subnet: '10.0.0.0/24'
    pools:
      - pool: '10.0.0.100 - 10.0.0.200'
    option_data:
      - name: 'routers'
        data: '10.0.0.1'

# In datacenter/dc1.yaml - add datacenter-specific subnets
kea::dhcp4::subnets:
  dc1-servers:
    subnet: '10.1.0.0/24'
    pools:
      - pool: '10.1.0.100 - 10.1.0.200'
    option_data:
      - name: 'routers'
        data: '10.1.0.1'
  dc1-workstations:
    subnet: '10.1.1.0/24'
    pools:
      - pool: '10.1.1.100 - 10.1.1.200'
    option_data:
      - name: 'routers'
        data: '10.1.1.1'

# In nodes/dhcp01.example.com.yaml - node-specific subnets
kea::dhcp4::subnets:
  guest-wifi:
    subnet: '172.16.0.0/24'
    pools:
      - pool: '172.16.0.50 - 172.16.0.250'
    valid_lifetime: 1800
    option_data:
      - name: 'routers'
        data: '172.16.0.1'
```

With deep merge enabled in your Hiera configuration, all these subnets will be combined.
The module creates:

1. **Individual subnet files** in `/etc/kea/subnets4.d/` (e.g., `management.json`, `dc1-servers.json`)
2. **A master include file** at `/etc/kea/kea-dhcp4-subnets.json` that uses Kea's `<?include?>`
   directive to pull in each individual subnet file
3. **The main config** `kea-dhcp4.conf` includes the master subnets file

This creates a proper include chain:
```
kea-dhcp4.conf → kea-dhcp4-subnets.json → subnets4.d/*.json
```

**Subnet IDs are auto-generated** from the subnet name if not explicitly provided. This uses
`fqdn_rand()` to create a stable, unique ID based on the subnet's Hiera key name. You can
still manually specify an `id` if you need a specific value.

Each subnet in the hash supports the following keys:

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `id` | Integer | No | Unique subnet ID (auto-generated if not provided) |
| `subnet` | String | Yes | CIDR notation (e.g., '192.168.1.0/24') |
| `pools` | Array | No | Address pool definitions |
| `option_data` | Array | No | DHCP options for this subnet |
| `reservations` | Array | No | Host reservations |
| `relay` | Hash | No | Relay agent configuration |
| `interface` | String | No | Interface for directly connected subnets |
| `valid_lifetime` | Integer | No | Override global valid lifetime |
| `renew_timer` | Integer | No | Override global T1 timer |
| `rebind_timer` | Integer | No | Override global T2 timer |
| `option_def` | Hash | No | Custom (non-standard) DHCP Options |
| `extra_config` | Hash | No | Additional Kea configuration options |

### Modular DHCPv6 Subnet Configuration

DHCPv6 subnets work the same way, using `kea::dhcp6::subnets`:

```yaml
kea::dhcp6::subnets:
  office-v6:
    subnet: '2001:db8:1::/64'
    pools:
      - pool: '2001:db8:1::100 - 2001:db8:1::1ff'
    option_data:
      - name: 'dns-servers'
        data: '2001:db8:1::1'

  guest-v6:
    subnet: '2001:db8:2::/64'
    pools:
      - pool: '2001:db8:2::100 - 2001:db8:2::fff'
    # Prefix delegation for guest CPE devices
    pd_pools:
      - prefix: '2001:db8:8000::'
        prefix_len: 48
        delegated_len: 56
```

DHCPv6 subnets support additional keys:

| Key | Type | Description |
|-----|------|-------------|
| `pd_pools` | Array | Prefix delegation pool definitions |
| `interface_id` | String | Interface ID for relay agent subnet selection |
| `preferred_lifetime` | Integer | Override preferred lifetime |
| `rapid_commit` | Boolean | Enable rapid commit for this subnet |

### Shared Networks

Shared networks allow multiple subnets to share a common physical network segment. This is
useful for scenarios like network migrations, VoIP deployments, or multi-tenant environments.

Each shared network is managed as an individual JSON file in `/etc/kea/shared-networks4.d/`
(or `shared-networks6.d/` for DHCPv6), using Kea's `<?include?>` directive for clean
separation.

```yaml
# DHCPv4 shared networks
kea::dhcp4::shared_networks:
  office-floor1:
    interface: 'eth0'
    option_data:
      - name: 'domain-name'
        data: 'floor1.example.com'
    subnets:
      - subnet: '192.168.1.0/24'
        pools:
          - pool: '192.168.1.100 - 192.168.1.200'
        option_data:
          - name: 'routers'
            data: '192.168.1.1'
      - subnet: '192.168.2.0/24'
        pools:
          - pool: '192.168.2.100 - 192.168.2.200'
        option_data:
          - name: 'routers'
            data: '192.168.2.1'

  guest-network:
    interface: 'eth1'
    subnets:
      - subnet: '10.0.0.0/24'
        pools:
          - pool: '10.0.0.50 - 10.0.0.250'
        valid_lifetime: 1800
```

```yaml
# DHCPv6 shared networks
kea::dhcp6::shared_networks:
  office-v6:
    interface: 'eth0'
    subnets:
      - subnet: '2001:db8:1::/64'
        pools:
          - pool: '2001:db8:1::100 - 2001:db8:1::1ff'
      - subnet: '2001:db8:2::/64'
        pools:
          - pool: '2001:db8:2::100 - 2001:db8:2::1ff'
```

Each shared network supports:

| Key | Type | Description |
|-----|------|-------------|
| `name` | String | Network name (defaults to Hiera key) |
| `interface` | String | Interface for directly connected networks |
| `relay` | Hash | Relay agent configuration |
| `option_data` | Array | DHCP options for all subnets in network |
| `subnets` | Array | Array of subnet definitions |
| `valid_lifetime` | Integer | Override valid lifetime for all subnets |
| `extra_config` | Hash | Additional Kea configuration options |

## Reference

### Main Class Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `repo_version` | String | `'3-0'` | Kea repository version |
| `manage_repo` | Boolean | `true` | Whether to manage the apt repository |
| `dhcp4` | Hash | `undef` | DHCPv4 configuration hash |
| `dhcp6` | Hash | `undef` | DHCPv6 configuration hash |
| `ddns` | Hash | `undef` | DHCP-DDNS configuration hash |
| `hooks_package` | Boolean | `true` | Install open source hooks package |
| `mysql_backend` | Boolean | `false` | Install MySQL backend support |
| `postgresql_backend` | Boolean | `false` | Install PostgreSQL backend support |
| `config_dir` | String | `'/etc/kea'` | Configuration directory |
| `run_dir` | String | `'/run/kea'` | Runtime directory |
| `log_dir` | String | `'/var/log/kea'` | Log directory |
| `lib_dir` | String | `'/var/lib/kea'` | Library/state directory |

### DHCPv4/DHCPv6 Hash Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enable` | Boolean | - | Enable this component (required) |
| `service_ensure` | String | `'running'` | Service state |
| `service_enable` | Boolean | `true` | Enable service at boot |
| `interfaces` | Array | `['*']` | Interfaces to listen on |
| `valid_lifetime` | Integer | `4000` | Lease valid lifetime (seconds) |
| `renew_timer` | Integer | `1000` | T1 renew timer (seconds) |
| `rebind_timer` | Integer | `2000` | T2 rebind timer (seconds) |
| `calculate_tee_times` | Boolean | - | Auto-calculate T1/T2 from valid_lifetime |
| `t1_percent` | Float | - | T1 as percentage of valid_lifetime (0.0-1.0) |
| `t2_percent` | Float | - | T2 as percentage of valid_lifetime (0.0-1.0) |
| `store_extended_info` | Boolean | - | Store extended info in leases |
| `allocator` | String | - | Address allocation strategy (`iterative`, `random`, `flq`) |
| `subnets` | Array | `[]` | Subnet definitions |
| `option_data` | Array | `[]` | Global DHCP options |
| `reservations` | Array | `[]` | Global host reservations |
| `hooks_libraries` | Array | `[]` | Hook libraries to load |
| `client_classes` | Array | `[]` | Client class definitions |
| `lease_database` | Hash | memfile | Lease database config |
| `logging` | Hash | defaults | Logging configuration |
| `control_socket` | Hash | enabled | Control socket config |
| `sanity_checks` | Hash | - | Lease sanity checking config |
| `expired_leases_processing` | Hash | - | Expired lease reclamation config |
| `ha` | Hash | - | High availability configuration (see [HA section](#high-availability-ha)) |

### DHCPv6 Additional Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `preferred_lifetime` | Integer | `3000` | Preferred lifetime (seconds) |
| `pd_allocator` | String | - | Prefix delegation allocator (`iterative`, `random`, `flq`) |

### Expired Leases Processing

Configure how Kea reclaims expired leases:

```yaml
kea::dhcp4:
  enable: true
  expired_leases_processing:
    reclaim_timer_wait_time: 10
    flush_reclaimed_timer_wait_time: 25
    hold_reclaimed_time: 3600
    max_reclaim_leases: 100
    max_reclaim_time: 250
    unwarned_reclaim_cycles: 5
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `reclaim_timer_wait_time` | Integer | `10` | Seconds between reclamation cycles |
| `flush_reclaimed_timer_wait_time` | Integer | `25` | Seconds between flushing reclaimed leases to DB |
| `hold_reclaimed_time` | Integer | `3600` | Seconds to hold reclaimed lease in DB |
| `max_reclaim_leases` | Integer | `100` | Max leases to reclaim per cycle |
| `max_reclaim_time` | Integer | `250` | Max milliseconds for reclamation cycle |
| `unwarned_reclaim_cycles` | Integer | `5` | Cycles without warning before logging |

### Sanity Checks

Configure lease sanity checking:

```yaml
kea::dhcp4:
  enable: true
  sanity_checks:
    lease_checks: 'fix-del'  # Options: none, warn, fix, fix-del, del
```

### DDNS Hash Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enable` | Boolean | - | Enable DDNS (required) |
| `ip_address` | String | `'127.0.0.1'` | Listen address |
| `port` | Integer | `53001` | Listen port |
| `dns_server_timeout` | Integer | `500` | DNS server timeout (ms) |
| `forward_ddns` | Hash | `{}` | Forward DNS update config |
| `reverse_ddns` | Hash | `{}` | Reverse DNS update config |
| `tsig_keys` | Array | `[]` | TSIG key definitions |

## Limitations

- Only supports Debian and Ubuntu (Debian family)
- Does not manage the Kea Control Agent (by design)
- Database schema initialization must be done manually when using MySQL/PostgreSQL backends

## Development

### Running Tests

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake

# Run only spec tests
bundle exec rake spec

# Run with code coverage
COVERAGE=yes bundle exec rake spec

# Run linting
bundle exec rake lint

# Validate syntax
bundle exec rake syntax

# Check metadata.json
bundle exec rake metadata_lint
```

### Contributing

Contributions are welcome! Please ensure:

1. All tests pass: `bundle exec rake spec`
2. Code passes `puppet-lint`: `bundle exec rake lint`
3. New features include appropriate spec tests
4. Templates generate valid JSON (test with `kea-dhcp4 -t /etc/kea/kea-dhcp4.conf`)

## License

Apache-2.0
