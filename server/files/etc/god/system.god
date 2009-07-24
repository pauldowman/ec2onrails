God.watch do |w|
  w.name = "system-checks"
  w.start = true
  w.interval  = 10.minutes

 
  w.behavior(:clean_pid_file)

    
  # lifecycle
  w.lifecycle do |on|
    on.condition(:disk_usage) do |c| 
      c.mount_point = "/" 
      c.above = 75
      c.notify = "default"
    end 

    on.condition(:disk_usage) do |c| 
      c.mount_point = "/mnt"
      c.above = 75
      c.notify = "default"
    end 
    
    on.condition(:memory_usage) do |c|
      c.above = 80.percent
      c.times = [3, 5] # 3 out of 5 intervals
      c.notify = "default"
    end
  
    on.condition(:cpu_usage) do |c|
      c.above = 90.percent
      c.times = [5, 8]
      c.notify = "default"
    end        
  end
 
end
