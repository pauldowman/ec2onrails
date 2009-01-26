if File.exists?('/etc/init.d/dkim-filter')
  #we have it installed, so lets register it with God
  God.watch do |w|
    w.name = 'dkim_filter'
    w.group = 'app'
    w.autostart = false

    w.start    = "/etc/init.d/dkim-filter start" 
    w.stop     = "/etc/init.d/dkim-filter stop" 
    w.restart  = "/etc/init.d/dkim-filter restart" 

    w.pid_file = "/var/run/dkim-filter/dkim-filter.pid"

    default_configurations(w)
    create_pid_dir(w)
    restart_if_resource_hog(w, :memory_usage => 20.megabytes, :cpu_usage => 10.percent)
    monitor_lifecycle(w)
  end
end

