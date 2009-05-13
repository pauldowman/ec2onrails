God.watch do |w|
  w.name  = "memcached"
  w.group = 'memcache'
  w.autostart = false

  w.start     = "/etc/init.d/memcached start"
  w.stop      = "/etc/init.d/memcached stop"
  w.restart   = "/etc/init.d/memcached restart"
  w.pid_file  = "/var/run/memcached.pid"

  default_configurations(w)
  w.grace     = 10.seconds
 
  restart_if_resource_hog(w, :memory_usage => false)
  monitor_lifecycle(w)
end
