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
    end 

    on.condition(:disk_usage) do |c| 
      c.mount_point = "/mnt"
      c.above = 75
    end 
    
    # on.condition(:memory_usage) do |c|
    #   c.above = 170.megabytes
    #   c.times = [3, 5] # 3 out of 5 intervals
    # end
  
    on.condition(:cpu_usage) do |c|
      c.above = 90.percent
      c.times = [5, 8]
    end
        
  end
 
end
