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

require 'ec2onrails/version'
require 'ec2onrails/capistrano_utils'
include Ec2onrails::CapistranoUtils

Capistrano::Configuration.instance.load do

  unless ec2onrails_config
    raise "ec2onrails_config variable not set. (It should be a hash.)"
  end
  
  cfg = ec2onrails_config

  set :ec2onrails_version, Ec2onrails::VERSION::STRING
  set :image_id_32_bit, Ec2onrails::VERSION::AMI_ID_32_BIT
  set :image_id_64_bit, Ec2onrails::VERSION::AMI_ID_64_BIT
  set :deploy_to, "/mnt/app"
  set :use_sudo, false
  set :user, "app"
  
  make_admin_role_for :web
  make_admin_role_for :app
  make_admin_role_for :db
  
  roles[:web_admin].to_s
  roles[:app_admin].to_s
  roles[:db_admin].to_s
  
  # override default start/stop/restart tasks
  namespace :deploy do
    desc <<-DESC
      Overrides the default Capistrano deploy:start, directly calls \
      /etc/init.d/mongrel
    DESC
    task :start, :roles => :app do
      run "/etc/init.d/mongrel start"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:stop, directly calls \
      /etc/init.d/mongrel
    DESC
    task :stop, :roles => :app do
      run "/etc/init.d/mongrel stop"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, directly calls \
      /etc/init.d/mongrel
    DESC
    task :restart, :roles => :app do
      run "/etc/init.d/mongrel restart"
    end
  end
  
  namespace :ec2onrails do
    desc <<-DESC
      Show the AMI id's of the current images for this version of \
      EC2 on Rails.
    DESC
    task :ami_ids, :roles => [:web, :db, :app] do
      puts "32-bit server image for EC2 on Rails #{ec2onrails_version}: #{image_id_32_bit}"
      puts "64-bit server image for EC2 on Rails #{ec2onrails_version}: #{image_id_64_bit}"
    end
    
    desc <<-DESC
      Start a new server instance and prepare it for a cold deploy.
    DESC
    task :setup, :roles => [:web, :db, :app] do
      ec2.start_instance
      server.set_timezone
      server.install_packages
      server.install_gems
      server.deploy_files
      server.restart_services
      deploy.setup
      server.set_roles
      db.create
    end
    
    desc <<-DESC
      Deploy and restore database from S3
    DESC
    task :restore_db_and_deploy, :roles => [:web, :db, :app] do
      db.recreate
      deploy.update_code
      deploy.symlink
      # don't need to migrate because we're restoring the db
      db.restore
      deploy.restart
    end
    
    namespace :ec2 do      
      desc <<-DESC
        Start an instance, using the AMI of the correct version to match this gem.
      DESC
      task :start_instance, :roles => [:web, :db, :app] do
        # TODO
      end
      
      desc <<-DESC
        Set default firewall rules.
      DESC
      task :configure_firewall do
        # TODO
      end
    end
    
    namespace :db do
      desc <<-DESC
        [internal] Load configuration info for the production database from \
        config/database.yml.
      DESC
      task :load_config, :roles => :db do
        db_config = YAML::load(ERB.new(File.read("config/database.yml")).result)['production']
        cfg[:production_db_name] = db_config['database']
        cfg[:production_db_user] = db_config['username']
        cfg[:production_db_password] = db_config['password']
        cfg[:production_db_host] = db_config['host']
        cfg[:production_db_socket] = db_config['socket']
        
        if (cfg[:production_db_host].nil? || cfg[:production_db_host].empty?) && 
          (cfg[:production_db_host] != 'localhost' || cfg[:production_db_host] != '127.0.0.1') && 
          (cfg[:production_db_socket].nil? || cfg[:production_db_socket].empty?)
            raise "ERROR: missing database config. Make sure database.yml contains a 'production' section with either 'host: localhost' or 'socket: /var/run/mysqld/mysqld.sock'."
        end
        
        [cfg[:production_db_name], cfg[:production_db_user], cfg[:production_db_password]].each do |s|
          if s.nil? || s.empty?
            raise "ERROR: missing database config. Make sure database.yml contains a 'production' section with a database name, user, and password."
          elsif s.match(/['"]/)
            raise "ERROR: database config string '#{s}' contains quotes."
          end
        end
      end
      
      desc <<-DESC
        Create the MySQL production database. Assumes there is no MySQL root \
        password. To create a MySQL root password create a task that's run \
        after this task using an after hook.
      DESC
      task :create, :roles => :db do
        on_rollback { drop }
        load_config
        run "echo 'create database #{cfg[:production_db_name]};' | mysql -u root"
        run "echo \"grant all on #{cfg[:production_db_name]}.* to '#{cfg[:production_db_user]}'@'%' identified by '#{cfg[:production_db_password]}';\" | mysql -u root"
      end
      
      desc <<-DESC
        Drop the MySQL production database. Assumes there is no MySQL root \
        password. If there is a MySQL root password, create a task that removes \
        it and run that task before this one using a before hook.
      DESC
      task :drop, :roles => :db do
        load_config
        run "echo 'drop database if exists #{cfg[:production_db_name]};' | mysql -u root"
      end
      
      desc <<-DESC
        db:drop and db:create.
      DESC
      task :recreate, :roles => :db do
        drop
        create
      end
      
      desc <<-DESC
        Set a root password for MySQL, using the variable mysql_root_password \
        if it is set. If this is done db:drop won't work.
      DESC
      task :set_root_password, :roles => :db do
        if cfg[:mysql_root_password]
          run "echo 'set password for root@localhost=password('#{cfg[:mysql_root_password]}');' | mysql -u root"
        end
      end
      
      desc <<-DESC
        Dump the MySQL database to the S3 bucket specified by \
        ec2onrails_config[:archive_to_bucket]. The filename will be \
        "app-<timestamp>.sql.gz".
      DESC
      task :archive, :roles => [:db] do
        run "/usr/local/ec2onrails/bin/backup_app_db.rb #{cfg[:archive_to_bucket]} app-#{Time.new.strftime('%y-%m-%d--%H-%M-%S')}.sql.gz"
      end
      
      desc <<-DESC
        Restore the MySQL database from the S3 bucket specified by \
        ec2onrails_config[:restore_from_bucket]. The archive filename is \
        expected to be the default, "app.sql.gz".
      DESC
      task :restore, :roles => [:db] do
        run "/usr/local/ec2onrails/bin/restore_app_db.rb #{cfg[:restore_from_bucket]}"
      end
    end
    
    namespace :server do
      desc <<-DESC
        Tell the servers what roles they are in. This configures them with \
        the appropriate settings for each role, and starts and/or stops the \
        relevant services.
      DESC
      task :set_roles, :roles => [:web_admin, :db_admin, :app_admin] do
        # TODO generate this based on the roles that actually exist so arbitrary new ones can be added
        sudo "/usr/local/ec2onrails/bin/set_roles.rb web=#{hostnames_for_role(:web)} app=#{hostnames_for_role(:app)} db_primary=#{hostnames_for_role(:db, :primary => true)}"
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
        sudo "gem update -y --no-rdoc --no-ri"
      end
      
      desc <<-DESC
        Install extra Ubuntu packages. Set ec2onrails_config[:packages], it \
        should be an array of strings.
        NOTE: the package installation will be non-interactive, if the packages \
        require configuration either log in as 'admin' and run \
        'dpkg-reconfigure packagename' or replace the package's config files \
        using the 'ec2onrails:deploy_config_files' task.
      DESC
      task :install_packages, :roles => [:web_admin, :db_admin, :app_admin] do
        if cfg[:packages] && cfg[:packages].any?
          run "export DEBIAN_FRONTEND=noninteractive; sudo aptitude -q -y install #{cfg[:packages].join(' ')}"
        end
      end
      
      desc <<-DESC
        Install extra rubygems. Set ec2onrails_config[:rubygems], it should \
        be with an array of strings.
      DESC
      task :install_gems, :roles => [:web_admin, :db_admin, :app_admin] do
        if cfg[:rubygems] && cfg[:rubygems].any?
          sudo "gem install #{cfg[:rubygems].join(' ')} -y --no-rdoc --no-ri" do |ch, str, data|
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
        http://packages.ubuntu.com/cgi-bin/search_contents.pl?searchmode=filelist&word=tzdata&version=gutsy&arch=all&page=1&number=all \
        Remove 'usr/share/zoneinfo/' from the filename, and use the last \
        directory and file as the value. For example 'Africa/Abidjan' or \
        'posix/GMT' or 'Canada/Eastern'.
      DESC
      task :set_timezone, :roles => [:web_admin, :db_admin, :app_admin] do
        if cfg[:timezone]
          sudo "bash -c 'echo #{cfg[:timezone]} > /etc/timezone'"
          sudo "cp /usr/share/zoneinfo/#{cfg[:timezone]} /etc/localtime"
        end
      end
      
      desc <<-DESC
        Deploy a set of config files to the server, the files will be owned by \
        root. This doesn't delete any files from the server.
      DESC
      task :deploy_files, :roles => [:web_admin, :db_admin, :app_admin] do
        if cfg[:server_config_files_root]
          begin
            # TODO use Zlib to support Windows
            file = '/tmp/config_files.tgz'
            run_local "tar zcf #{file} -C '#{cfg[:server_config_files_root]}' ."
            put File.read(file), file
            sudo "tar zxvf #{file} -o -C /"
          ensure
            rm_rf file
            sudo "rm -f #{file}"
          end
        end
      end
      
      desc <<-DESC
        Restart a set of services. Set ec2onrails_config[:services_to_restart] \
        to an array of strings. It's assumed that each service has a script \
        in /etc/init.d
      DESC
      task :restart_services, :roles => [:web_admin, :db_admin, :app_admin] do
        if cfg[:services_to_restart] && cfg[:services_to_restart].any?
          cfg[:services_to_restart].each do |service|
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
    end
    
  end
end
