# rolling restart idea plagiarized directly from:
# http://blog.pragmatic-it.de/articles/2008/07/09/poor-mans-rolling-restart-for-thin-god
#NOTE: this doesn't do what you think it does...
#      requests are queued up at nginx and requests start to time out
restart_time  = 2.seconds #how long to restart the entire cluster
rolling_delay = (restart_time / @configs.web_num_instances.to_f).ceil
@configs.web_port_range.each_with_index do |port, i|
  God.watch do |w|
    w.name = "mongrel_#{port}"
    w.group = 'app'
    w.uid = @configs.user
    w.gid = @configs.group
    w.autostart = false

    w.start     = "mongrel_rails cluster::start    -C /etc/mongrel_cluster/app.yml --clean --only #{port}"
    w.stop      = "mongrel_rails cluster::stop    -C /etc/mongrel_cluster/app.yml --clean --only #{port}"
    w.restart   = "sleep #{i*rolling_delay}; mongrel_rails cluster::restart -C /etc/mongrel_cluster/app.yml --clean --only #{port}"

    w.pid_file  = "/mnt/app/shared/log/mongrel.#{port}.pid"
    w.grace     = 60.seconds

    default_configurations(w)
    restart_if_resource_hog(w, :memory_usage => 170.megabytes) do |restart|
      #NOTE: this will hit every instance, meaning every minute you have a hit for every port you have a mongrel on.  
      #      adding the port number to the call just to help with making this obvious in the logs
      restart.condition(:http_response_code) do |c|
        c.code_is_not = %w(200 304)
        c.host = '127.0.0.1'
        c.path = "/?port=#{port}" 
        c.port = port
        c.timeout = 10.seconds
        c.times = 2
        c.interval = 1.minute
      end
    end
    
    monitor_lifecycle(w)
  end
end