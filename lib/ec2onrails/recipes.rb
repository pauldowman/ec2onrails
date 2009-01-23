#    This file is part of EC2 on Rails.
#    http://rubyforge.org/projects/ec2onrails/
#
#    Copyright 2007 Paul Dowman, http://pauldowman.com/
#
#    EC2 on Rails is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    EC2 on Rails is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'
include FileUtils
require 'tmpdir'
require 'pp'
require 'zlib'
require 'archive/tar/minitar'
include Archive::Tar

require 'ec2onrails/version'
require 'ec2onrails/capistrano_utils'
include Ec2onrails::CapistranoUtils



Dir[File.join(File.dirname(__FILE__), "recipes/*")].find_all{|x| File.file? x}.each do |recipe|
  require recipe 
end


Capistrano::Configuration.instance.load do

  unless ec2onrails_config
    raise "ec2onrails_config variable not set. (It should be a hash.)"
  end
  
  cfg = ec2onrails_config
  
  #:apache or :nginx
  cfg[:web_proxy_server] ||= :apache

  set :ec2onrails_version, Ec2onrails::VERSION::STRING
  set :image_id_32_bit, Ec2onrails::VERSION::AMI_ID_32_BIT
  set :image_id_64_bit, Ec2onrails::VERSION::AMI_ID_64_BIT
  set :deploy_to, "/mnt/app"
  set :use_sudo, false
  set :user, "app"

  #in case any changes were made to the configs, like changing the number of mongrels
  before "deploy:cold", "ec2onrails:server:grant_sudo_access", "ec2onrails:setup"
  
  after "deploy:symlink", "ec2onrails:server:set_roles", "ec2onrails:server:init_services"
  after "deploy:cold", "ec2onrails:db:init_backup", "ec2onrails:db:optimize", "ec2onrails:server:restrict_sudo_access"
  after "ec2onrails:server:install_gems", "ec2onrails:server:add_gem_sources"

  #NOTE: some default setups (like engineyard's) do some symlinking of config files after
  # deploy:update_code.  The ordering here matters as we need to have those symlinks in place
  # but we need to have the gems in place before the rails env is loaded up, or else it will
  # fail.  By adding it to the callback queue AFTER all the tasks have loaded up, we make sure
  # it is done at the very end.  
  #
  # *IF* you had tasks also triggered after update_code that run rake tasks 
  # (like compressing javascript and stylesheets), move those over to before "deploy:symlink"
  # and you'll be set!
  on :load do
    after "deploy:update_code", "ec2onrails:server:run_rails_rake_gems_install"
  end  

  
  namespace :ec2onrails do
    desc <<-DESC
      Show the AMI id's of the current images for this version of \
      EC2 on Rails.
    DESC
    task :ami_ids do
      puts "32-bit server image for EC2 on Rails #{ec2onrails_version}: #{image_id_32_bit}"
      puts "64-bit server image for EC2 on Rails #{ec2onrails_version}: #{image_id_64_bit}"
    end
    
    desc <<-DESC
      Copies the public key from the server using the external "ssh"
      command because Net::SSH, which is used by Capistrano, needs it.
      This will only work if you have an ssh command in the path.
      If Capistrano can successfully connect to your EC2 instance you
      don't need to do this. It will copy from the first server in the
      :app role, this can be overridden by specifying the HOST 
      environment variable
    DESC
    task :get_public_key_from_server do
      host = find_servers_for_task(current_task).first.host
      privkey = ssh_options[:keys][0]
      pubkey = "#{privkey}.pub"
      msg = <<-MSG
      Your first key in ssh_options[:keys] is #{privkey}, presumably that's 
      your EC2 private key. The public key will be copied from the server 
      named '#{host}' and saved locally as #{pubkey}. Continue? [y/n]
      MSG
      choice = nil
      while choice != "y" && choice != "n"
        choice = Capistrano::CLI.ui.ask(msg).downcase
        msg = "Please enter 'y' or 'n'."
      end
      if choice == "y"
        run_local "scp -i '#{privkey}' app@#{host}:.ssh/authorized_keys #{pubkey}"
      end
    end
    
    desc <<-DESC
      Prepare a newly-started instance for a cold deploy.
    DESC
    task :setup do
      ec2onrails.server.allow_sudo do
        server.set_mail_forward_address
        server.set_timezone
        # server.install_packages
        # server.install_gems
        server.upgrade_and_install_all
        server.deploy_files
        server.setup_web_proxy
        server.set_roles
        server.enable_ssl if cfg[:enable_ssl]
        server.set_rails_env
        server.restart_services
        deploy.setup
        db.create
        server.harden_server
        db.enable_ebs
        db.set_root_password
      end
    end

  end
end


