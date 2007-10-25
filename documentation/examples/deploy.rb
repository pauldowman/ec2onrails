# This is a sample Capistrano config file for EC2 on Rails.

set :application, "yourapp"

set :deploy_via, :copy       # optional, see Capistrano docs for details
set :copy_strategy, :export  # optional, see Capistrano docs for details

set :repository, "http://svn.foo.com/svn/#{application}/trunk"

# NOTE: for some reason Capistrano requires you to have both the public and
# the private key in the same folder, the public key should have the 
# extension ".pub".
ssh_options[:keys] = %w(/home/you/.ssh/your-ec2-key)

# Your EC2 instances
role :web, "ec2-12-xx-xx-xx.z-1.compute-1.amazonaws.com"
role :app, "ec2-34-xx-xx-xx.z-1.compute-1.amazonaws.com"
role :db,  "ec2-56-xx-xx-xx.z-1.compute-1.amazonaws.com", :primary => true

# EC2 on Rails config
set :ec2onrails_config, {
  # S3 bucket used by the ec2onrails:db:archive task
  :restore_from_bucket => "your-bucket",
  
  # S3 bucket used by the ec2onrails:db:restore task
  :archive_to_bucket => "your-other-bucket",
  
  # Set a root password for MySQL. Run "cap ec2onrails:db:set_root_password"
  # to enable this. This is optional, and after doing this the
  # ec2onrails:db:drop task won't work, but be aware that MySQL accepts 
  # connections on the public network interface (you should block the MySQL
  # port with the firewall anyway). 
  :mysql_root_password => "your-mysql-root-password",
  
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
