nginx_enabled = system("which nginx 2>&1 > /dev/null")

God.watch do |w|
  applog(w, :info, "web: using #{nginx_enabled ? 'nginx' : 'apache2'}")

  if nginx_enabled
    w.name = "nginx"
    w.start = "/etc/init.d/nginx start"
    w.stop = "/etc/init.d/nginx stop"
    w.restart = "/etc/init.d/nginx restart"
    w.pid_file = "/var/run/nginx.pid"  
  else
    w.name = "apache"
    w.start = "/etc/init.d/apache2 start"
    w.stop = "/etc/init.d/apache2 stop"
    w.restart = "/etc/init.d/apache2 restart"
    w.pid_file = "/var/run/apache2.pid"
  end
  w.grace = 5.seconds
  w.group = 'web'
  w.autostart = false

  default_configurations(w)
  restart_if_resource_hog(w, :memory_usage => 250.megabytes) do |restart|
    restart.condition(:http_response_code) do |c|
      c.host = '127.0.0.1'
      c.port = 80
      c.path = '/'
      c.code_is_not = 200
      c.timeout = 15.seconds
      c.times = [3, 5] # 3 out of 5 intervals
    end
  end
  
  monitor_lifecycle(w)
end