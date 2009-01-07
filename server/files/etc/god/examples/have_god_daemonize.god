# here we have an example script which is not daemonized.  
#
# Make sure that mq_poller requires the right libraries and runs in a loop...

God.watch do |w|
  w.name = 'queue'
  w.group = 'app'
  
  w.uid = @configs.user
  w.gid = @configs.group
  w.autostart = false
  
  w.start = "/usr/local/ec2onrails/bin/rails_env #{APP_ROOT}/script/mq_poller"

  default_configurations(w)
  restart_if_resource_hog(w)
  monitor_lifecycle(w)
end
