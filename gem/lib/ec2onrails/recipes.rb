#    This file is part of EC2 on Rails.
#    http://code.google.com/p/EC2 on Rails/
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


Capistrano::Configuration.instance.load do

  set :image_id, "ami-0cf61365"
  set :deploy_to, "/mnt/app"
  set :use_sudo, false
  
  # If the HOST environment variable is set use it to override the 
  # value of host
  set :host, ENV['HOST'] || host
  
  role :web, "app@#{host}"
  role :app, "app@#{host}"
  role :db,  "app@#{host}", :primary => true
  
  role :web_admin, "admin@#{host}", :no_release => true
  role :app_admin, "admin@#{host}", :no_release => true
  role :db_admin,  "admin@#{host}", :no_release => true, :primary => true

  # override default start/stop/restart tasks
  namespace :deploy do
    desc <<-DESC
      Overrides the default Capistrano deploy:start, directly calls \
      /usr/local/EC2 on Rails/bin/mongrel_cluster_ctl_wrapper
    DESC
    task :start, :except => { :no_release => true } do
      run "/usr/local/EC2 on Rails/bin/mongrel_cluster_ctl_wrapper start"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:stop, directly calls \
      /usr/local/EC2 on Rails/bin/mongrel_cluster_ctl_wrapper
    DESC
    task :stop, :except => { :no_release => true } do
      run "/usr/local/EC2 on Rails/bin/mongrel_cluster_ctl_wrapper stop"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, directly calls \
      /usr/local/EC2 on Rails/bin/mongrel_cluster_ctl_wrapper
    DESC
    task :restart, :except => { :no_release => true } do
      run "/usr/local/EC2 on Rails/bin/mongrel_cluster_ctl_wrapper restart"
    end
  end
  
  namespace :ec2onrails do
    desc <<-DESC
      Start an instance, using the AMI of the correct version to match this gem.
    DESC
    task :start_instance, :roles => [:web, :db, :app] do
      # TODO
#      ec2 = EC2::Base.new(:access_key_id => access_key_id, :secret_access_key => secret_access_key)
#      ec2.run_instances(:image_id => image_id, :key_name => key_name, :group_id => group_id)
      # wait until image is booted
    end
    
    desc <<-DESC
      Start a new server instance and prepare it for a cold deploy.
    DESC
    task :bootstrap, :roles => [:web, :db, :app] do
      start_instance
      set_timezone
      upgrade_and_install_all
      deploy_files
      restart_services
      deploy.setup
      create_db
    end
    
    desc <<-DESC
      Bootstrap and cold deploy.
    DESC
    task :launch, :roles => [:web, :db, :app] do
      bootstrap
      deploy.cold
      # migrations?
    end
    
    desc <<-DESC
      Deploy and restore database from S3
    DESC
    task :restore_db_and_deploy, :roles => [:web, :db, :app] do
      ec2onrails.recreate_db
      deploy.update_code
      deploy.symlink
      # don't need to migrate because we're restoring the db
      ec2onrails.restore_db
      deploy.restart
    end

    desc <<-DESC
      Load configuration info for the production database from \
      config/database.yml.
    DESC
    task :load_db_config, :roles => :db do
      db_config = YAML::load(ERB.new(File.read("config/database.yml")).result)['production']
      set :production_db_name, db_config['database']
      set :production_db_user, db_config['username']
      set :production_db_password, db_config['password']
      
      [production_db_name, production_db_user, production_db_password].each do |s|
        if s.match(/['"]/)
          raise "ERROR: database config string '#{s}' contains quotes."
        end
      end
    end
    
    desc <<-DESC
      Create the MySQL production database. Assumes there is no MySQL root \
      password. To create a MySQL root password create a task that's run \
      after this task using an after hook.
    DESC
    task :create_db, :roles => :db do
      on_rollback { drop_db }
      load_db_config
      run "echo 'create database #{production_db_name};' | mysql -u root"
      run "echo \"grant all on #{production_db_name}.* to '#{production_db_user}'@'localhost' identified by '#{production_db_password}';\" | mysql -u root"
    end
    
    desc <<-DESC
      Drop the MySQL production database. Assumes there is no MySQL root \
      password. If there is a MySQL root password, create a task that removes \
      it and run that task before this one using a before hook.
    DESC
    task :drop_db, :roles => :db do
      load_db_config
      run "echo 'drop database if exists #{production_db_name};' | mysql -u root"
    end
    
    desc <<-DESC
      drop_db and create_db.
    DESC
    task :recreate_db, :roles => :db do
      drop_db
      create_db
    end
    
    desc <<-DESC
      Dump the MySQL database to the S3 bucket specified by a variable named \
      "backup_to_bucket".
    DESC
    task :archive_db, :roles => [:db] do
      run "/usr/local/aws/bin/backup_app_db.rb #{backup_to_bucket}"
    end
    
    desc <<-DESC
      Restore the MySQL database from the S3 bucket specified by a variable named \
      "restore_from_bucket".
    DESC
    task :restore_db, :roles => [:db] do
      run "/usr/local/aws/bin/restore_app_db.rb #{restore_from_bucket}"
    end
    
    desc <<-DESC
      Upgrade to the newest versions of all Ubuntu packages.
    DESC
    task :upgrade_packages, :roles => [:web_admin, :db_admin, :app_admin] do
      sudo "aptitude -q update"
      run "export DEBIAN_FRONTEND=noninteractive; sudo aptitude -q -y dist-upgrade"
    end
    
    desc <<-DESC
      Upgrade to the newest versions of all rubygems.
    DESC
    task :upgrade_gems, :roles => [:web_admin, :db_admin, :app_admin] do
      sudo "gem update -y"
    end
    
    desc <<-DESC
      Install extra Ubuntu packages. Set a variable named :packages with an \
      array of strings:
      set :packages, %w(libmagick logwatch)
      NOTE: the package installation will be non-interactive, if the packages \
      require configuration either log in as 'admin' and run \
      'dpkg-reconfigure packagename' or replace the package's config files \
      using the 'ec2onrails:deploy_config_files' task.
    DESC
    task :install_packages, :roles => [:web_admin, :db_admin, :app_admin] do
      if defined? packages && packages && packages.any?
        run "export DEBIAN_FRONTEND=noninteractive; sudo aptitude -q -y install #{packages.join(' ')}"
      end
    end
    
    desc <<-DESC
      Install extra rubygems. Set a variable named :rubygems with an array \
      of strings: \
      set :rubygems, %w(hpricot rmagick)
    DESC
    task :install_gems, :roles => [:web_admin, :db_admin, :app_admin] do
      if defined? rubygems && rubygems && rubygems.any?
        sudo "gem install #{rubygems.join(' ')} -y" do |ch, str, data|
          ch[:data] ||= ""
          ch[:data] << data
          if data =~ />\s*$/
            puts "The gem command is asking for a number:"
            choice = STDIN.gets
            ch.send_data(choice)
          else
            puts data
          end
        end
      end
    end
    
    desc <<-DESC
      A convenience task to upgrade existing packages and gems and install \
      specified new ones.
    DESC
    task :upgrade_and_install_all, :roles => [:web_admin, :db_admin, :app_admin] do
      upgrade_packages
      upgrade_gems
      install_packages
      install_gems
    end
    
    desc <<-DESC
      Set the timezone using the value of the variable named timezone. \
      Valid options for timezone can be determined by the contents of \
      /usr/share/zoneinfo, which can be seen here: \
      http://packages.ubuntu.com/cgi-bin/search_contents.pl?searchmode=filelist&word=tzdata&version=feisty&arch=all&page=1&number=all \
      Remove 'usr/share/zoneinfo/' from the filename, and use the last \
      directory and file as the value. For example 'Africa/Abidjan' or \
      'posix/GMT' or 'Canada/Eastern'.
    DESC
    task :set_timezone, :roles => [:web_admin, :db_admin, :app_admin] do
      if defined? timezone && timezone
        sudo "bash -c 'echo #{timezone} > /etc/timezone'"
        sudo "cp /usr/share/zoneinfo/#{timezone} /etc/localtime"
      end
    end
    
    desc <<-DESC
      Deploy a set of config files to the server, the files will be owned by \
      root. This doesn't delete any files from the server.
    DESC
    task :deploy_files, :roles => [:web_admin, :db_admin, :app_admin] do
      if defined? server_config_files_root && server_config_files_root
        # temporary hack:
        system "rsync -rlvzcC --rsh='ssh -l root -i #{ssh_options[:keys][0]}' #{server_config_files_root}/ '#{host}:/'"
      end
    end
    
    desc <<-DESC
    DESC
    task :restart_services, :roles => [:web_admin, :db_admin, :app_admin] do
      if defined? services_to_restart && services_to_restart && services_to_restart.any?
        services_to_restart.each do |service|
          sudo "/etc/init.d/#{service} restart"
        end
      end
    end
    
    desc <<-DESC
    DESC
    task :enable_mail_server, :roles => [:web_admin, :db_admin, :app_admin] do
      # TODO
    end
    
    desc <<-DESC
    DESC
    task :add_user, :roles => [:web_admin, :db_admin, :app_admin] do
      # TODO
    end
    
    desc <<-DESC
    DESC
    task :run_script, :roles => [:web_admin, :db_admin, :app_admin] do
      # TODO
    end
    
    desc <<-DESC
    DESC
    task :archive_logs, :roles => [:web_admin, :db_admin, :app_admin] do
      # TODO
    end
    
    desc <<-DESC
      Set default firewall rules.
    DESC
    task :configure_firewall, :roles => [:web, :db, :app] do
      # TODO
    end
  end
end