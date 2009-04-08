God.watch do |w|
  w.name = 'mysql'
  w.group = 'db_primary'
  w.autostart = false
  
  w.start    = "/etc/init.d/mysql start" 
  w.stop     = "/etc/init.d/mysql stop;" 
  w.restart  = "/etc/init.d/mysql restart" 
  
  w.pid_file = "/var/run/mysqld/mysqld.pid"
  w.grace    = 60.seconds

  default_configurations(w)
  restart_if_resource_hog(w, :memory_usage => false)
  monitor_lifecycle(w)
end