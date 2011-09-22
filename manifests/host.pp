# host.pp - the master host of the munin installation
# Copyright (C) 2007 David Schmitt <david@schmitt.edv-bus.at>
# See LICENSE for the full license granted to you.

class munin::host
{
  include munin
  include munin::client
  
  module_dir {
    [ "munin/nodes" ]:
  }
  
  package {
    [ "munin", "nmap"]:
      ensure => installed;
  }
  
  File <<| tag == 'munin' |>>
  
  concatenated_file { "/etc/munin/munin.conf":
    dir => $NODESDIR,
    header => "/etc/munin/munin.conf.header",
  }
  
  file {
    "/etc/munin/munin.conf.header":
      content => template('munin/munin.conf.header.erb'),
      owner => root,
      group => 0,
      mode => 0644,
      before => File["/etc/munin/munin.conf"];
  }
  
  file {
    ["/var/log/munin/munin-update.log", "/var/log/munin/munin-limits.log", 
     "/var/log/munin/munin-graph.log", "/var/log/munin/munin-html.log"]:
       ensure => present,
       owner => munin,
       group => root,
       mode => 640;
  }

  munin::plugin {
    munin_stats:
      config => "  user munin\n";

    munin_update:
      config => "  user munin\n";
  }
}

class munin::snmp_collector
{
	file { 
		"${module_dir_path}/munin/create_snmp_links":
			source => "puppet:///modules/munin/create_snmp_links.sh",
			mode => 755, owner => root, group => root;
	}

	exec { "create_snmp_links":
		command => "${module_dir_path}/munin/create_snmp_links $NODESDIR",
		require => File["snmp_links"],
		timeout => "2048",
		schedule => daily
	}
}

define munin::apache_site()
{
	apache::site {
		$name:
			ensure => present,
			content => template("munin/site.conf")
	}
}
