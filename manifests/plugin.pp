# plugin.pp - configure a specific munin plugin
# Copyright (C) 2007 David Schmitt <david@schmitt.edv-bus.at>
# See LICENSE for the full license granted to you.

define munin::plugin (
  $ensure = "present",
  $script_path = "/usr/share/munin/plugins",
  $config = '')
{
  debug("munin_plugin: name=$name, ensure=$ensure, script_path=$script_path")
  $plugin = "/etc/munin/plugins/$name"
  $plugin_conf = "/etc/munin/plugin-conf.d/$name.conf"
  
  include munin::client
  
  case $ensure {
    "absent": {
      debug ( "munin_plugin: suppressing $plugin" )
      file {
        $plugin:
          ensure => absent;
      } 
    }
    default: {
      $plugin_src = $ensure ? {
        "present" => $name,
        default => $ensure
      }
      debug("munin_plugin: making $plugin using src: $plugin_src")
      file {
        $plugin:
	  ensure => "$script_path/${plugin_src}",
	  require => Package["munin-node"],
	  notify => Service["munin-node"],
      }
    }
  }
  case $config {
    '': {
      debug("no config for $name")
      file {
        $plugin_conf:
          ensure => absent
      }
    }
    default: {
      case $ensure {
	absent: {
	  debug("removing config for $name")
	  file {
            $plugin_conf:
              ensure => absent
          }
	}
	default: {
	  debug("creating $plugin_conf")
	  file { $plugin_conf:
	    content => "[${name}]\n$config\n",
	    mode => 0644,
            owner => root,
            group => root,
            notify => Service['munin-node'];
	  }
	}
      }
    }
  }
}

define munin::remoteplugin($ensure = "present", $source, $config = '') {
  case $ensure {
    "absent": {
      munin::plugin{
        $name:
          ensure => absent
      }
    }
    default: {
      file {
	"${module_dir_path}/munin/plugins/${name}":
	  source => $source,
	  owner => root,
          group => root,
          mode => 0755;
      }
      munin::plugin {
        $name:
	  ensure => $ensure,
	  config => $config,
	  script_path => "${module_dir_path}/munin/plugins";
      }
    }
  }
}

class munin::plugins::base {
  file {
    [ "/etc/munin/plugins", "/etc/munin/plugin-conf.d" ]:
      source => "puppet:///modules/common/empty",
      ensure => directory,
      checksum => mtime,
      ignore => '.ignore',
      recurse => true,
      purge => true,
      force => true, 
      owner => root,
      group => root,
      mode => 0755,
      notify => Service['munin-node'];
    "/etc/munin/plugin-conf.d/munin-node":
      source => [ "puppet:///modules/munin/munin-node.${lsbdistcodename}",
                  "puppet:///modules/munin/munin-node" ],
      owner => root,
      group => root,
      mode => 0644,
      notify => Service['munin-node'],
      before => Package['munin-node'];
  }
}

# handle if_ and if_err_ plugins
class munin::plugins::interfaces inherits munin::plugins::base {
  $ifs = gsub(split($munin_interfaces, " "), "(.+)", "if_\\1")
  $if_errs = gsub(split($munin_interfaces, " "), "(.+)", "if_err_\\1")
  plugin {
    $ifs: ensure => "if_";
    $if_errs: ensure => "if_err_";
  }
}

class munin::plugins::linux inherits munin::plugins::base {
  plugin {
    [ df_abs, forks, iostat, memory, processes, cpu, df_inode, irqstats,
      netstat, open_files, swap, df, entropy, interrupts, load, open_inodes,
      vmstat
      ]:
	ensure => present;
      acpi: 
	ensure => $acpi_available;
  }
  include munin::plugins::interfaces
}

class munin::plugins::redhat inherits munin::plugins::linux {
  cron {
    'munin_yum_update':
      command => '/usr/share/munin/plugins/yum update',
      user => root,
      hour => '*/2',
      minute => 33;
  }

  exec {
    'munin_yum_update_create':
      command => '/usr/share/munin/plugins/yum update',
      creates => '/var/lib/munin/plugin-state/yum.state',
      user => root,
      cwd => '/';
  }
  
  plugin {
    [ diskstats, iostat_ios, proc_pri, fw_packets, threads, uptime, users, yum ]:
      ensure => present;
  }
}

class munin::plugins::debian inherits munin::plugins::base {
  plugin {
    apt_all:
      ensure => present;
  }
}

class munin::plugins::vserver inherits munin::plugins::base {
  plugin {
    [ netstat, processes ]:
      ensure => present;
  }
}
