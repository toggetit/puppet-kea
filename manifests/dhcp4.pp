# @summary
#   Manages the Kea DHCPv4 server.
#
# @api private
#
class kea::dhcp4 {
  assert_private()

  # Extract configuration from the dhcp4 hash
  $config = $kea::dhcp4

  # Merge defaults with provided config
  $service_ensure = pick($config['service_ensure'], 'running')
  $service_enable = pick($config['service_enable'], true)
  $config_file    = pick($config['config_file'], "${kea::config_dir}/kea-dhcp4.conf")

  # HA auto-detection: determine this_server from FQDN if not specified
  $ha_config = $config['ha']
  if $ha_config != undef {
    $ha_this_server = $ha_config['this_server'] ? {
      undef   => $facts['networking']['fqdn'],
      default => $ha_config['this_server'],
    }

    # Validate that this_server exists in peers
    if !($ha_this_server in $ha_config['peers'].keys) {
      fail("HA this_server '${ha_this_server}' must be one of the defined peers: ${ha_config['peers'].keys.join(', ')}")
    }

    # Validate mode and role compatibility
    $ha_mode = $ha_config['mode']
    $ha_config['peers'].each |$name, $peer| {
      $role = $peer['role']
      case $ha_mode {
        'hot-standby': {
          if !($role in ['primary', 'standby']) {
            fail("HA mode 'hot-standby' requires roles 'primary' or 'standby', got '${role}' for peer '${name}'")
          }
        }
        'load-balancing': {
          if !($role in ['primary', 'secondary']) {
            fail("HA mode 'load-balancing' requires roles 'primary' or 'secondary', got '${role}' for peer '${name}'")
          }
        }
        'passive-backup': {
          if !($role in ['primary', 'backup']) {
            fail("HA mode 'passive-backup' requires roles 'primary' or 'backup', got '${role}' for peer '${name}'")
          }
        }
        default: {
          fail("Unknown HA mode: ${ha_mode}")
        }
      }
    }
  } else {
    $ha_this_server = undef
  }

  # Determine hooks library path based on architecture
  $hooks_lib_dir = $facts['os']['architecture'] ? {
    'aarch64' => '/usr/lib/aarch64-linux-gnu/kea/hooks',
    'arm64'   => '/usr/lib/aarch64-linux-gnu/kea/hooks',
    default   => '/usr/lib/x86_64-linux-gnu/kea/hooks',
  }

  # Include subnets management (creates subnets.d directory and resources)
  contain kea::dhcp4::subnets

  # Install DHCPv4 package
  package { 'isc-kea-dhcp4':
    ensure  => installed,
    require => Class['kea::install'],
  }

  # Configuration file
  file { $config_file:
    ensure       => file,
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    content      => epp('kea/kea-dhcp4.conf.epp', {
        'config'         => $config,
        'config_dir'     => $kea::config_dir,
        'run_dir'        => $kea::run_dir,
        'log_dir'        => $kea::log_dir,
        'lib_dir'        => $kea::lib_dir,
        'ha_this_server' => $ha_this_server,
        'hooks_lib_dir'  => $hooks_lib_dir,
    }),
    validate_cmd => '/usr/sbin/kea-dhcp4 -t %',
    require      => Package['isc-kea-dhcp4'],
    notify       => Service['isc-kea-dhcp4-server'],
  }

  # Service management
  # Note: On Debian/Ubuntu, the real service name is isc-kea-dhcp4-server
  service { 'isc-kea-dhcp4-server':
    ensure     => $service_ensure,
    enable     => $service_enable,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package['isc-kea-dhcp4'],
      File[$config_file],
      Class['kea::dhcp4::subnets'],
    ],
  }
}
