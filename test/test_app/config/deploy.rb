set :application, "test_app"

ssh_options[:keys] = [ENV['KEY'], "#{ENV['HOME']}/.ssh/ec2-key"]

raise "please add HOST=ec2-xxx.xx... on the command line" unless ENV['HOST']
set :host, ENV['HOST']
role :web, host
role :db,  host, :primary => true

set :repository, "."
set :scm, :none
set :deploy_via, :copy

set :rails_env, "production"

# EC2 on Rails config
set :ec2onrails_config, {
  :packages => [],
  :rubygems => [],
  :timezone => "Canada/Eastern",
  :services_to_restart => %w(sysklogd)
}
