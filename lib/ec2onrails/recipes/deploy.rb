Capistrano::Configuration.instance(:must_exist).load do
  cfg = ec2onrails_config

  # override default start/stop/restart tasks to use god
  namespace :deploy do
    desc <<-DESC
      Overrides the default Capistrano deploy:start, uses \
      'god start app'
    DESC
    task :start, :roles => :app do
      sudo "god start app"
      # sudo "god monitor app"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:stop, uses \
      'god stop app'
    DESC
    task :stop, :roles => :app do
      # sudo "god unmonitor app"
      sudo "god stop app"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, uses \
      'god restart app'
    DESC
    task :restart, :roles => :app do
      sudo "god restart app"
    end
  end
end