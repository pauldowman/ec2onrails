Capistrano::Configuration.instance(:must_exist).load do
  cfg = ec2onrails_config

  # override default start/stop/restart tasks to use god
  namespace :deploy do
    desc <<-DESC
      Overrides the default Capistrano deploy:start.
    DESC
    task :start, :roles => :web do
      run "touch #{current_release}/tmp/restart.txt"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:stop.
    DESC
    task :stop, :roles => :web do
      sudo "god stop app"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart.
    DESC
    task :restart, :roles => :web do
      run "touch #{current_release}/tmp/restart.txt"
    end
  end
end