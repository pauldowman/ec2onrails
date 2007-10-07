set :application, "yourapp"
set :deploy_via, :copy
set :copy_strategy, :export

set :repository, "http://svn.foo.com/svn/trunk"

ssh_options[:keys] = %w(/home/you/.ssh/your-ec2-key)

set :host, ENV['HOST'] || "www.foo.com"
role :web, host
role :app, host
role :db,  host, :primary => true

# EC2 on Rails config
set :ec2onrails_config, {
  :restore_from_bucket => "your-bucket",
  :archive_to_bucket => "your-other-bucket",
  :packages => %w(logtail imagemagick),
  :rubygems => %w(RedCloth hpricot rmagick),
  :timezone => "Canada/Eastern",
  :server_config_files_root => "../server_config",
  :services_to_restart => %w(apache2 postfix syslog)
}
