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

  # make an "admin" role for each role, and create arrays containing
  # the names of admin roles and non-admin roles for convenience
  set :all_admin_role_names, []
  set :all_non_admin_role_names, []
  roles.keys.clone.each do |name|
    make_admin_role_for(name)
    all_non_admin_role_names << name
    all_admin_role_names << "#{name.to_s}_admin".to_sym
  end  
  
  after "deploy:symlink", "ec2onrails:server:set_roles"
  
  # override default start/stop/restart tasks
  namespace :deploy do
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, uses \
      /etc/init.d/mongrel
    DESC
    task :start, :roles => :app_admin do
      run_init_script("mongrel", "start")
      sudo "monit -g app monitor all"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, uses \
      /etc/init.d/mongrel
    DESC
    task :stop, :roles => :app_admin do
      sudo "monit -g app unmonitor all"
      run_init_script("mongrel", "stop")
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, uses \
      /etc/init.d/mongrel
    DESC
    task :restart, :roles => :app_admin do
      sudo "monit -g app unmonitor all"
      run_init_script("mongrel", "restart")
      sudo "monit -g app monitor all"
    end
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
    task :setup, :roles => all_admin_role_names do
      server.set_admin_mail_forward_address
      server.set_timezone
      server.install_packages
      server.install_gems
      server.deploy_files
      server.enable_ssl
      server.set_rails_env
      server.restart_services
      deploy.setup
      server.set_roles
      sudo "monit -g app unmonitor all"
      db.create
    end
    
    desc <<-DESC
      Deploy and restore database from S3
    DESC
    task :restore_db_and_deploy do
      db.recreate
      deploy.update_code
      deploy.symlink
      # don't need to migrate because we're restoring the db
      db.restore
    end
    
    namespace :ec2 do
      desc <<-DESC
      DESC
      task :configure_firewall do
        # TODO
      end
    end
    
    namespace :db do
      desc <<-DESC
        [internal] Load configuration info for the database from 
        config/database.yml, and start mysql (it must be running
        in order to interact with it).
      DESC
      task :load_config do
        db_config = YAML::load(ERB.new(File.read("config/database.yml")).result)[rails_env]
        cfg[:db_name] = db_config['database']
        cfg[:db_user] = db_config['username']
        cfg[:db_password] = db_config['password']
        cfg[:db_host] = db_config['host']
        cfg[:db_socket] = db_config['socket']
        
        if (cfg[:db_host].nil? || cfg[:db_host].empty?) && 
          (cfg[:db_host] != 'localhost' || cfg[:db_host] != '127.0.0.1') && 
          (cfg[:db_socket].nil? || cfg[:db_socket].empty?)
            raise "ERROR: missing database config. Make sure database.yml contains a '#{rails_env}' section with either 'host: localhost' or 'socket: /var/run/mysqld/mysqld.sock'."
        end
        
        [cfg[:db_name], cfg[:db_user], cfg[:db_password]].each do |s|
          if s.nil? || s.empty?
            raise "ERROR: missing database config. Make sure database.yml contains a '#{rails_env}' section with a database name, user, and password."
          elsif s.match(/['"]/)
            raise "ERROR: database config string '#{s}' contains quotes."
          end
        end
      end
      
      desc <<-DESC
        Create the MySQL database. Assumes there is no MySQL root \
        password. To create a MySQL root password create a task that's run \
        after this task using an after hook.
      DESC
      task :create, :roles => :db do
        on_rollback { drop }
        load_config
        run %{mysql -u root -e "create database if not exists #{cfg[:db_name]};"}
        run %{mysql -u root -e "grant all on #{cfg[:db_name]}.* to '#{cfg[:db_user]}'@'%' identified by '#{cfg[:db_password]}';"}
        run %{mysql -u root -e "grant reload on *.* to '#{cfg[:db_user]}'@'%' identified by '#{cfg[:db_password]}';"}
        run %{mysql -u root -e "grant super on *.* to '#{cfg[:db_user]}'@'%' identified by '#{cfg[:db_password]}';"}
        # Do a full backup of the newly-created db so the automatic incremental backups make sense
        run "/usr/local/ec2onrails/bin/backup_app_db.rb"
      end
      
      desc <<-DESC
        Drop the MySQL database. Assumes there is no MySQL root \
        password. If there is a MySQL root password, create a task that removes \
        it and run that task before this one using a before hook.
      DESC
      task :drop, :roles => :db do
        load_config
        run %{mysql -u root -e "drop database if exists #{cfg[:db_name]};"}
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
          run %{mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('#{cfg[:mysql_root_password]}') WHERE User='root'; FLUSH PRIVILEGES;"}
        end
      end
      
      desc <<-DESC
        Dump the MySQL database to the S3 bucket specified by \
        ec2onrails_config[:archive_to_bucket]. The filename will be \
        "app-<timestamp>.sql.gz".
      DESC
      task :archive, :roles => :db do
        run "/usr/local/ec2onrails/bin/backup_app_db.rb --noreset --bucket #{cfg[:archive_to_bucket]} --dir database-#{Time.new.strftime('%Y-%m-%d--%H-%M-%S')}"
      end
      
      desc <<-DESC
        Restore the MySQL database from the S3 bucket specified by \
        ec2onrails_config[:restore_from_bucket]. The archive filename is \
        expected to be the default, "mysqldump.sql.gz".
      DESC
      task :restore, :roles => :db do
        run "/usr/local/ec2onrails/bin/restore_app_db.rb --bucket #{cfg[:restore_from_bucket]} --dir #{cfg[:restore_from_bucket_subdir]}"
      end
    end
    
    namespace :server do
      desc <<-DESC
        Tell the servers what roles they are in. This configures them with \
        the appropriate settings for each role, and starts and/or stops the \
        relevant services.
      DESC
      task :set_roles, :roles => all_admin_role_names do
        # TODO generate this based on the roles that actually exist so arbitrary new ones can be added
        roles = {
          :web =>        hostnames_for_role(:web),
          :app =>        hostnames_for_role(:app),
          :db_primary => hostnames_for_role(:db, :primary => true),
          :memcache =>   hostnames_for_role(:memcache)
        }
        roles_yml = YAML::dump(roles)
        put roles_yml, "/tmp/roles.yml"
        sudo "cp /tmp/roles.yml /etc/ec2onrails"
        sudo "/usr/local/ec2onrails/bin/set_roles.rb"
      end

      desc <<-DESC
        Change the default value of RAILS_ENV on the server. Technically
        this changes the server's mongrel config to use a different value
        for "environment". The value is specified in :rails_env
      DESC
      task :set_rails_env, :roles => all_admin_role_names do
        rails_env = fetch(:rails_env, "production")
        sudo "/usr/local/ec2onrails/bin/set_rails_env #{rails_env}"
        deploy.restart
      end
      
      desc <<-DESC
        Upgrade to the newest versions of all Ubuntu packages.
      DESC
      task :upgrade_packages, :roles => all_admin_role_names do
        sudo "aptitude -q update"
        run "export DEBIAN_FRONTEND=noninteractive; sudo aptitude -q -y dist-upgrade"
      end
      
      desc <<-DESC
        Upgrade to the newest versions of all rubygems.
      DESC
      task :upgrade_gems, :roles => all_admin_role_names do
        sudo "gem update --system --no-rdoc --no-ri"
        sudo "gem update --no-rdoc --no-ri" do |ch, str, data|
          ch[:data] ||= ""
          ch[:data] << data
          if data =~ />\s*$/
            puts data
            choice = Capistrano::CLI.ui.ask("The gem command is asking for a number:")
            ch.send_data("#{choice}\n")
          else
            puts data
          end
        end
        
      end
      
      desc <<-DESC
        Install extra Ubuntu packages. Set ec2onrails_config[:packages], it \
        should be an array of strings.
        NOTE: the package installation will be non-interactive, if the packages \
        require configuration either log in as 'admin' and run \
        'dpkg-reconfigure packagename' or replace the package's config files \
        using the 'ec2onrails:server:deploy_files' task.
      DESC
      task :install_packages, :roles => all_admin_role_names do
        if cfg[:packages] && cfg[:packages].any?
          run "export DEBIAN_FRONTEND=noninteractive; sudo aptitude -q -y install #{cfg[:packages].join(' ')}"
        end
      end
      
      desc <<-DESC
        Install extra rubygems. Set ec2onrails_config[:rubygems], it should \
        be with an array of strings.
      DESC
      task :install_gems, :roles => all_admin_role_names do
        if cfg[:rubygems]
          cfg[:rubygems].each do |gem|
            sudo "gem install #{gem} --no-rdoc --no-ri" do |ch, str, data|
              ch[:data] ||= ""
              ch[:data] << data
              if data =~ />\s*$/
                puts data
                choice = Capistrano::CLI.ui.ask("The gem command is asking for a number:")
                ch.send_data("#{choice}\n")
              else
                puts data
              end
            end
          end
        end
      end
      
      desc <<-DESC
        A convenience task to upgrade existing packages and gems and install \
        specified new ones.
      DESC
      task :upgrade_and_install_all, :roles => all_admin_role_names do
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
      task :set_timezone, :roles => all_admin_role_names do
        if cfg[:timezone]
          sudo "bash -c 'echo #{cfg[:timezone]} > /etc/timezone'"
          sudo "cp /usr/share/zoneinfo/#{cfg[:timezone]} /etc/localtime"
        end
      end
      
      desc <<-DESC
        Deploy a set of config files to the server, the files will be owned by \
        root. This doesn't delete any files from the server. This is intended
        mainly for customized config files for new packages installed via the \
        ec2onrails:server:install_packages task. Subdirectories and files \
        inside here will be placed within the same directory structure \
        relative to the root of the server's filesystem.
      DESC
      task :deploy_files, :roles => all_admin_role_names do
        if cfg[:server_config_files_root]
          begin
            filename = "config_files.tar"
            local_file = "#{Dir.tmpdir}/#{filename}"
            remote_file = "/tmp/#{filename}"
            FileUtils.cd(cfg[:server_config_files_root]) do
              File.open(local_file, 'wb') { |tar| Minitar.pack(".", tar) }
            end
            put File.read(local_file), remote_file
            sudo "tar xvf #{remote_file} -o -C /"
          ensure
            rm_rf local_file
            run "rm -f #{remote_file}"
          end
        end
      end
      
      desc <<-DESC
        Restart a set of services. Set ec2onrails_config[:services_to_restart] \
        to an array of strings. It's assumed that each service has a script \
        in /etc/init.d
      DESC
      task :restart_services, :roles => all_admin_role_names do
        if cfg[:services_to_restart] && cfg[:services_to_restart].any?
          cfg[:services_to_restart].each do |service|
            run_init_script(service, "restart")
          end
        end
      end
      
      desc <<-DESC
      DESC
      task :set_admin_mail_forward_address, :roles => all_admin_role_names do
        put cfg[:admin_mail_forward_address], "/home/admin/.forward"
      end

      desc <<-DESC
        Enable ssl for the web server. The SSL cert file should be in
        /etc/ssl/certs/default.pem and the SSL key file should be in
        /etc/ssl/private/default.key (use the deploy_files task).
      DESC
      task :enable_ssl, :roles => :web_admin do
        if cfg[:enable_ssl]
          sudo "a2enmod ssl"
          sudo "a2ensite default-ssl"
        end
      end
    end
    
  end
end
