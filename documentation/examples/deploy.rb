# This is a sample Capistrano config file for EC2 on Rails.

set :application, "yourapp"
set :deploy_via, :copy
set :copy_strategy, :export

set :repository, "http://svn.foo.com/svn/#{application}/trunk"

ssh_options[:keys] = %w(/home/you/.ssh/your-ec2-key)

set :host, ENV['HOST'] || "www.foo.com"
role :web, host
role :app, host
role :db,  host, :primary => true

# EC2 on Rails config
set :ec2onrails_config, {
  # S3 bucket used by the ec2onrails:db:archive task
  :restore_from_bucket => "your-bucket",
  
  # S3 bucket used by the ec2onrails:db:restore task
  :archive_to_bucket => "your-other-bucket",
  
  # Any extra Ubuntu packages to install if desired
  :packages => %w(logwatch imagemagick),
  
  # Any extra RubyGems to install if desired
  :rubygems => %w(RedCloth hpricot rmagick),
  
  # Set the server timezone. run "cap -e ec2onrails:server:set_timezone" for details
  :timezone => "Canada/Eastern",
  
  # Files to deploy to the server, It's intended mainly for
  # customized config files for new packages installed via the 
  # ec2onrails:server:install_packages task. 
  :server_config_files_root => "../server_config",
  
  # If config files are deployed, some services might need to be restarted
  :services_to_restart => %w(apache2 postfix sysklogd)
}
