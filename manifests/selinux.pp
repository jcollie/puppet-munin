class munin::selinux {
  include selinux

  if ($operatingsystem == 'Fedora') {
    selinux::selmodule_compiled {
      'muninpuppet':
        content => template('munin/muninpuppet.te.erb');
    }
  }
}
