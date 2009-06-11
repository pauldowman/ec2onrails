set :application, "test_app"

set :repository, "svn://rubyforge.org/var/svn/ec2onrails/trunk/test/#{application}"

ssh_options[:keys] = ["#{ENV['HOME']}/.ssh/ec2-key"]

set :host, ENV['HOST'] || ""
role :web, host
role :db,  host, :primary => true

set :rails_env, "production"

# EC2 on Rails config
set :ec2onrails_config, {
  :packages => [],
  :rubygems => [],
  :timezone => "Canada/Eastern",
  :server_config_files_root => "../server_configs",
  :services_to_restart => %w(sysklogd)
}
