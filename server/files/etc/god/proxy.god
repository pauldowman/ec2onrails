God.watch do |w|
  w.name  = "varnish"
  w.group = "proxy"
  w.autostart = false

  w.start     = "/etc/init.d/varnish start"
  w.stop      = "/etc/init.d/varnish stop"
  w.restart   = "/etc/init.d/varnish restart"
  w.pid_file  = "/var/run/varnishd.pid"
  w.grace     = 10.seconds
 
  default_configurations(w)
  
  # I'm not sure if it's very useful to monitor the varnishd memory usage,
  # because it writes the pid of the varnishd parent process in it's pid file,
  # so I assume that's what god is monitoring, and the varnishd parent starts
  # a child process to do the real work.
  # Also, the child process allocates all cache storage with malloc, so the
  # VSS size can get very large and depends on the amount of storage 
  # configured. It relies on the OS to page unused portions to disk, but at
  # the moment we don't have much swap configured (just using the defaults
  # from Eric Hammond's base image).
  restart_if_resource_hog(w, :memory_usage => 100.megabytes, :cpu_usage => 50.percent)
end

God.watch do |w|
  w.name  = "varnishncsa"
  w.group = "proxy"
  w.autostart = false

  w.start     = "/etc/init.d/varnishncsa start"
  w.stop      = "/etc/init.d/varnishncsa stop"
  w.restart   = "/etc/init.d/varnishncsa restart"
  w.pid_file  = "/var/run/varnishncsa.pid"
  w.grace     = 10.seconds
 
  default_configurations(w)

  restart_if_resource_hog(w, :memory_usage => 100.megabytes, :cpu_usage => 50.percent)
end
