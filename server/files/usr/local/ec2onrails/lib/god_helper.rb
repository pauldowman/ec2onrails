module  GodHelper
  require '/usr/local/ec2onrails/lib/roles_helper'
  require 'fileutils'

  def default_configurations(w)
    w.interval = 30.seconds
    w.grace    = 30.seconds


    w.behavior(:clean_pid_file)

    w.start_if do |start|
      start.condition(:process_running) do |c|
        c.notify = {:contacts => ['default'], :category => 'process not started...starting'}
        c.interval = 5.seconds
        c.running = false
      end
    end

    # w.start_if do |start|
    #   start.condition(:process_running) do |c|
    #     c.interval = 5.seconds
    #     c.running = false
    #     c.notify = {:contacts => ['default'], :category => 'process exited...restarting'}
    #   end
    # end

    # determine when process has finished starting
    # w.transition([:start, :restart], :up) do |on|
    #   on.condition(:process_running) do |c|
    #     c.running = true
    #   end
    # 
    #   # failsafe
    #   on.condition(:tries) do |c|
    #     c.times = 8
    #     c.within = 2.minutes
    #     c.transition = :start
    #   end
    # end
    # 
    # # start if process is not running
    # w.transition(:up, :start) do |on|
    #   on.condition(:process_exits) do |c|
    #     c.notify = {:contacts => ['default'], :category => 'process exited...restarting'}
    #   end
    # end
  end

  def restart_if_resource_hog(w, options={})
    options = {:memory_usage => 175.megabytes, :cpu_usage => 50.percent}.merge(options)
    w.restart_if do |restart|
      if options[:memory_usage]
        restart.condition(:memory_usage) do |c|
          c.notify = {:contacts => ['default'], :category => "process over #{options[:memory_usage]/1.megabyte}MB.  restarting"}
          c.above = options[:memory_usage]
          c.times = [3,5]
        end
      end

      if options[:cpu_usage]
        restart.condition(:cpu_usage) do |c|
          c.notify = {:contacts => ['default'], :category => "process over #{options[:cpu_usage]*100}%.  restarting"}
          c.above = options[:cpu_usage]
          c.times = 5
        end
      end

      yield restart if block_given?

    end
  end
  
  def create_pid_dir(w)
    pid_dir = File.dirname(w.pid_file)
    return if File.exist?(pid_dir)
  
    #we need to make sure it is writable...but include all the directories we created...
    starting_dir = pid_dir
    starting_dir = File.dirname(starting_dir) until File.exist?(File.dirname(starting_dir))

    FileUtils.mkdir_p(pid_dir)
    FileUtils.chown_R(w.uid, w.gid, starting_dir)
  end

  def monitor_lifecycle(w)
    # w.transition(:up, :unmonitored) do |on|
    w.lifecycle do |on|
      on.condition(:flapping) do |c|
        c.notify = {:contacts => ['default'], :category => 'process flapping...restarting'}
        c.to_state = [:start, :restart]
        c.times = 5
        c.within = 5.minutes
        c.transition = :unmonitored
        c.retry_in = 10.minutes
        c.retry_times = 5
        c.retry_within = 2.hours
      end
    end
    # w.lifecycle do |on|
    #   on.condition(:flapping) do |c| 
    #     c.notify = {:contacts => ['default'], :category => 'process flapping...restarting'}
    #     c.to_state = [:start, :restart] 
    #     c.times = 5 
    #     c.within = 60.seconds 
    #     c.retry_in = 10.minutes
    #     c.retry_times = 5
    #     c.retry_within = 2.hours
    #   end 
    # end
    
    # w.lifecycle do |on|
    #   on.condition(:flapping) do |c|
    #     c.to_state = [:start, :restart]
    #     c.times = 5
    #     c.within = 5.minutes
    #     c.transition = :unmonitored
    #     c.retry_in = 10.minutes
    #     c.retry_times = 5
    #     c.retry_within = 2.hours
    #   end
    # end
  end
  
  class Configs
     include Ec2onrails::RolesHelper
  end
  
end