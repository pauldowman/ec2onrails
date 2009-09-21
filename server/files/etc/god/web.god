God.watch do |w|
  w.name = "nginx"
  w.group = 'web'

  w.start = "/etc/init.d/nginx start"
  w.stop = "/etc/init.d/nginx stop"
  w.restart = "/etc/init.d/nginx restart"
  w.pid_file = "/var/run/nginx.pid"  
  w.autostart = false

  default_configurations(w)

  restart_if_resource_hog(w, :memory_usage => 250.megabytes) do |restart|
    restart.condition(:http_response_code) do |c|
      c.host = '127.0.0.1'
      c.port = in_role?(:proxy) ? 81 : 80
      c.path = '/nginx_status'
      c.code_is_not = 200
      c.timeout = 5.seconds
      c.times = [3, 5] # 3 out of 5 intervals
    end
  end
end
