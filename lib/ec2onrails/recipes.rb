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
  
  #:apache or :nginx
  cfg[:web_proxy_server] ||= :apache

  set :ec2onrails_version, Ec2onrails::VERSION::STRING
  set :image_id_32_bit, Ec2onrails::VERSION::AMI_ID_32_BIT
  set :image_id_64_bit, Ec2onrails::VERSION::AMI_ID_64_BIT
  set :deploy_to, "/mnt/app"
  set :use_sudo, false
  set :user, "app"

  #in case any changes were made to the configs, like changing the number of mongrels
  before "deploy:cold", "ec2onrails:server:grant_sudo_access"
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

  
  # override default start/stop/restart tasks
  namespace :deploy do
    desc <<-DESC
      Overrides the default Capistrano deploy:start, uses \
      'god start app'
    DESC
    task :start, :roles => :app do
      sudo "god start app"
      # sudo "god monitor app"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:stop, uses \
      'god stop app'
    DESC
    task :stop, :roles => :app do
      # sudo "god unmonitor app"
      sudo "god stop app"
    end
    
    desc <<-DESC
      Overrides the default Capistrano deploy:restart, uses \
      'god restart app'
    DESC
    task :restart, :roles => :app do
      sudo "god restart app"
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
    task :setup do
      ec2onrails.server.allow_sudo do
        server.set_mail_forward_address
        server.set_timezone
        server.install_packages
        server.install_gems
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
      end
    end
    
    desc <<-DESC
      Deploy and restore database from S3
    DESC
    task :restore_db_and_deploy do
      db.recreate
      deploy.update_code
      deploy.symlink
      db.restore
      deploy.migrations
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
        unless hostnames_for_role(:db, :primary => true).empty?
          db_config = YAML::load(ERB.new(File.read("config/database.yml")).result)[rails_env.to_s] || {}
          cfg[:db_name]     ||= db_config['database']
          cfg[:db_user]     ||= db_config['username'] || db_config['user'] 
          cfg[:db_password] ||= db_config['password']
          cfg[:db_host]     ||= db_config['host']
          cfg[:db_port]     ||= db_config['port']
          cfg[:db_socket]   ||= db_config['socket']
        
          if (cfg[:db_host].nil? || cfg[:db_host].empty?) && (cfg[:db_socket].nil? || cfg[:db_socket].empty?)
              raise "ERROR: missing database config. Make sure database.yml contains a '#{rails_env}' section with either 'host: hostname' or 'socket: /var/run/mysqld/mysqld.sock'."
          end
        
          [cfg[:db_name], cfg[:db_user], cfg[:db_password]].each do |s|
            if s.nil? || s.empty?
              raise "ERROR: missing database config. Make sure database.yml contains a '#{rails_env}' section with a database name, user, and password."
            elsif s.match(/['"]/)
              raise "ERROR: database config string '#{s}' contains quotes."
            end
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
        start
        sleep(5) #make sure the db has some time to start up!
        
        
        # remove the default test database, though sometimes it doesn't exist (perhaps it isn't there anymore?)
        run %{mysql -u root -e "drop database if exists test; flush privileges;"}
        
        # removing anonymous mysql accounts
        run %{mysql -u root -D mysql -e "delete from db where User = ''; flush privileges;"}
        run %{mysql -u root -D mysql -e "delete from user where User = ''; flush privileges;"}
        
        # qoting of database names allows special characters eg (the-database-name)
        # the quotes need to be double escaped. Once for capistrano and once for the host shell
        run %{mysql -u root -e "create database if not exists \\`#{cfg[:db_name]}\\`;"}
        run %{mysql -u root -e "grant all on \\`#{cfg[:db_name]}\\`.* to '#{cfg[:db_user]}'@'%' identified by '#{cfg[:db_password]}';"}
        run %{mysql -u root -e "grant reload on *.* to '#{cfg[:db_user]}'@'%' identified by '#{cfg[:db_password]}';"}
        run %{mysql -u root -e "grant super on *.* to '#{cfg[:db_user]}'@'%' identified by '#{cfg[:db_password]}';"}
      end
      
      desc <<-DESC
        Move the MySQL database to Amazon's Elastic Block Store (EBS), \
        which is a persistant data store for the cloud.
        OPTIONAL PARAMETERS:
          * SIZE: Pass in a number representing the GB's to hold, like 10. \
            It will default to 10 gigs.
          * VOLUME_ID: The volume_id to use for the mysql database    
        NOTE: keep track of the volume ID, as you'll want to keep this for your \
        records and probably add it to the :db role in your deploy.rb file \
        (see the ec2onrails sample deploy.rb file for additional information)
      DESC
      task :enable_ebs, :roles => :db, :only => { :primary => true } do        
        # based off of Eric's work:
        # http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1663&categoryID=100
        #
        # EXPLAINATION:
        # There is a lot going on here!  At the end, the setup should be:
        #   * create EBS volume if run outside of the ec2onrails:setup and 
        #     VOLUME_ID is not passed in when the cap task is called
        #   * EBS volume attached to /dev/sdh
        #   * format to xfs if new or do a xfs_check if previously existed
        #   * mounted on /var/local and update /etc/fstab
        #   * move /mnt/mysql_data -> /var/local/mysql_data
        #   * move /mnt/log/mysql  -> /var/local/log/mysql
        #   * change mysql configs by writing /etc/mysql/conf.d/mysql-ec2-ebs.cnf 
        #   * keep a copy of the mysql configs with the EBS volume, and if that volume is hooked into
        #     another instance, make sure the mysql configs that go with that volume are symlinked to /etc/mysql
        #   * update the file locations of the mysql binary logs in /mnt/log/mysql/mysql-bin.index
        #   * symlink the moved folders to their old position... makes the move to EBS transparent
        #   * Amazon doesn't contain EBS information in the meta-data API (yet).  So write
        #     /etc/ec2onrails/ebs_info.yml
        #     to contain the meta-data information that we need
        #
        # DESIGN CONSIDERATIONS
        #   * only moving mysql data to EBS.  seems the most obvious, and if we move over other components
        #     we will have to share that bandwidth (1 Gbps pipe to SAN).  So limiting to what we really need
        #   * not moving all mysql logic over (tmp scratch space stays local).  Again, this is to limit
        #     unnecessary bandwidth usage, PLUS, we are charged per million IO to EBS
        #
        # TODO:
        #  * make sure if we have a predefined ebs_vol_id, that we error out with a nice msg IF the zones do not match
        #  * can we move more of the mysql cache files back to the local disk and off of EBS, like the innodb table caches?
        #  * right now we force this task to only be run on one server; that works for db :primary => true
        #    But what is the best way to make this work if it needs to setup multiple servers (like db slaves)?
        #    I need to figure out how to do a direct mapping from a server definition to a ebs_vol_id
        #  * when we enable slaves and we setup ebs volumes on them, make it transparent to the user.  
        #    have the slave create a snapshot of the db.master volume, and then use that to mount from
        #  * need to do a rollback that if the volume is created but something fails, lets uncreate it?
        #    carefull though!  If it fails towards the end when information is copied over, it could cause information
        #    to be lost!
        #
        
        mysql_dir_root = '/var/local'
        block_mnt      = '/dev/sdh'
        servers = find_servers_for_task(current_task)
        
        if servers.empty?
          raise Capistrano::NoMatchingServersError, "`#{task.fully_qualified_name}' is only run for servers matching #{task.options.inspect}, but no servers matched"
        elsif servers.size > 1
          raise Capistrano::Error, "`#{task.fully_qualified_name}' is can only be run on one server, not #{server.size}"
        end
        
        vol_id = ENV['VOLUME_ID'] || servers.first.options[:ebs_vol_id]

        #HACK!  capistrano doesn't allow arguments to be passed in if we call this task as a method, like 'db.enable_ebs'
        #       the places where we do call it like that, we don't want to force a move to ebs, so....
        #       if the call frame is > 1 (ie, another task called it), do NOT force the ebs move
        no_force = task_call_frames.size > 1
        prev_created = !(vol_id.nil? || vol_id.empty?)
        #no vol_id was passed in, but perhaps it is already mounted...?
        prev_created = true if !quiet_capture("mount | grep -inr '#{mysql_dir_root}' || echo ''").empty?

        unless no_force && (vol_id.nil? || vol_id.empty?)
          zone = quiet_capture("/usr/local/ec2onrails/bin/ec2_meta_data.rb -key 'placement/availability-zone'")
          instance_id = quiet_capture("/usr/local/ec2onrails/bin/ec2_meta_data.rb -key 'instance-id'")

          unless prev_created
            puts "creating new ebs volume...."
            size = ENV["SIZE"] || "10"
            cmd = "ec2-create-volume -s #{size} -z #{zone} 2>&1"
            puts "running: #{cmd}"
            output = `#{cmd}`
            puts output
            vol_id = (output =~ /^VOLUME\t(.+?)\t/ && $1)
            puts "NOTE: remember that vol_id"
            sleep(2)          
          end
          vol_id.strip! if vol_id
          if quiet_capture("mount | grep -inr '#{block_mnt}' || echo ''").empty?
            cmd = "ec2-attach-volume -d #{block_mnt} -i #{instance_id} #{vol_id} 2>&1"
            puts "running: #{cmd}"
            output = `#{cmd}`
            puts output
            if output =~ /Client.InvalidVolume.ZoneMismatch/i              
              raise Exception, "The volume you are trying to attach does not reside in the zone of your instance.  Stopping!"
            end
            
            
            sleep(10)
          end
          
          ec2onrails.server.allow_sudo do
            # try to format the volume... if it is already formatted, lets run a check on
            # it to make sure it is ok, and then continue on
            # if errors, the device is busy...something else is going on here and it is already mounted... skip!
            if prev_created
              # Stop the db (mysql server) for cases where this is being run after the original run
              # If EBS partiion is already mounted and being used by mysql, it will fail when umount is run
              god_status = quiet_capture("sudo god status")
              god_status = god_status.empty? ? {} : YAML::load(god_status)
              start_stop_db = false
              start_stop_db = god_status['db']['mysql'] == 'up'
              if start_stop_db
                stop
                puts "Waiting for mysql to stop"
                sleep(10)
              end
              quiet_capture("sudo umount #{mysql_dir_root}") #unmount if need to
              sudo "xfs_check #{block_mnt}"
              # Restart the db if it 
              start if start_stop_db
            else
              sudo "mkfs.xfs #{block_mnt}"  
            end
            
            # if not added to /etc/fstab, lets do so
            sudo "sh -c \"grep -iqn '#{mysql_dir_root}' /etc/fstab || echo '#{block_mnt} #{mysql_dir_root} xfs noatime 0 0' >> /etc/fstab\""
            sudo "mkdir -p #{mysql_dir_root}"
            #if not already mounted, lets mount it
            sudo "sh -c \"mount | grep -iqn '#{mysql_dir_root}' || mount '#{mysql_dir_root}'\""

            #ok, now lets move the mysql stuff off of /mnt -> mysql_dir_root
            stop rescue nil #already stopped
            sudo "mkdir -p #{mysql_dir_root}/log"
            #move the data over, but keep a symlink to the new location for backwards compatibility
            #and do not do it if /mnt/mysql_data has already been moved
            quiet_capture("sudo sh -c 'test ! -d #{mysql_dir_root}/mysql_data && mv /mnt/mysql_data #{mysql_dir_root}/'")
            sudo "mv /mnt/mysql_data /mnt/mysql_data_old 2>/dev/null || echo"
            sudo "ln -fs #{mysql_dir_root}/mysql_data /mnt/mysql_data"

            #but keep the tmpdir on mnt
            sudo "sh -c 'mkdir -p /mnt/tmp/mysql && chown mysql:mysql /mnt/tmp/mysql'"
            #move the logs over, but keep a symlink to the new location for backwards compatibility
            #and do not do it if the logs have already been moved
            quiet_capture("sudo sh -c 'test ! -d #{mysql_dir_root}/log/mysql_data && mv /mnt/log/mysql #{mysql_dir_root}/log/'")
            sudo "ln -fs #{mysql_dir_root}/log/mysql /mnt/log/mysql"
            quiet_capture("sudo sh -c \"test -f #{mysql_dir_root}/log/mysql/mysql-bin.index && \
                  perl -pi -e 's%/mnt/log/%#{mysql_dir_root}/log/%' #{mysql_dir_root}/log/mysql/mysql-bin.index\"") rescue false
            
            if quiet_capture("test -d /var/local/etc/mysql && echo 'yes'").empty?
              txt = <<-FILE
[mysqld]
  datadir          = #{mysql_dir_root}/mysql_data
  tmpdir           = /mnt/tmp/mysql
  log_bin          = #{mysql_dir_root}/log/mysql/mysql-bin.log
  log_slow_queries = #{mysql_dir_root}/log/mysql/mysql-slow.log
FILE
              put txt, '/tmp/mysql-ec2-ebs.cnf'
              sudo 'mv /tmp/mysql-ec2-ebs.cnf /etc/mysql/conf.d/mysql-ec2-ebs.cnf'

              #keep a copy 
              sudo "rsync -aR /etc/mysql #{mysql_dir_root}/"
            end
            # lets use the mysql configs on the EBS volume
            sudo "mv /etc/mysql /etc/mysql.orig 2>/dev/null"
            sudo "ln -sf #{mysql_dir_root}/etc/mysql /etc/mysql"

            #just put a README on the drive so we know what this volume is for!
            txt = <<-FILE
This volume is setup to be used by Ec2onRails in conjunction with Amazon's EBS, for primary MySql database persistence.
RAILS_ENV: #{fetch(:rails_env, 'undefined')}
DOMAIN:    #{fetch(:domain, 'undefined')}

Modify this volume at your own risk
FILE
      
            put txt, "/tmp/VOLUME-README"
            sudo "mv /tmp/VOLUME-README #{mysql_dir_root}/VOLUME-README"
            #update the list of ebs volumes
            #TODO: abstract this away into a helper method!!
            #TODO: this first touch should *not* be needed... quiet_capture should return an empty string
            #      if the cat on a non-existant file fails (as it should).  this isn't causing issues
            #      for me, but a few users have complained.... bad gemspec or something?
            #      COMMENTING OUT for now to see if the recent gemspec update improved things...
            # ebs_info = quiet_capture("touch /etc/ec2onrails/ebs_info.yml")
            ebs_info = quiet_capture("cat /etc/ec2onrails/ebs_info.yml")
            ebs_info = ebs_info.empty? ? {} : YAML::load(ebs_info)
            ebs_info[mysql_dir_root] = {'block_loc' => block_mnt, 'volume_id' => vol_id} 
            put(ebs_info.to_yaml, "/tmp/ebs_info.yml")
            sudo "mv /tmp/ebs_info.yml /etc/ec2onrails/ebs_info.yml"
            #lets start it back up
            start  
          end #end of sudo
        end
      end
      
      
      desc <<-DESC
        [internal] Make sure the MySQL server has been started, just in case the db role 
        hasn't been set, e.g. when called from ec2onrails:setup.
        (But don't enable monitoring on it.)
      DESC
      task :start, :roles => :db do
        sudo "god start db"
        # sudo "god monitor db"
      end

      task :stop, :roles => :db do
        # sudo "god unmonitor db"
        sudo "god stop db"
      end
      
      
      desc <<-DESC
        Drop the MySQL database. Assumes there is no MySQL root \
        password. If there is a MySQL root password, create a task that removes \
        it and run that task before this one using a before hook.
      DESC
      task :drop, :roles => :db do
        load_config
        run %{mysql -u root -e "drop database if exists \\`#{cfg[:db_name]}\\`;"}
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
        Dump the MySQL database to ebs (if enabled) or the S3 bucket specified by \
        ec2onrails_config[:archive_to_bucket]. The filename will be \
        "database-archive/<timestamp>/dump.sql.gz".
      DESC
      task :archive, :roles => :db do
        run "/usr/local/ec2onrails/bin/backup_app_db.rb --bucket #{cfg[:archive_to_bucket]} --dir #{cfg[:archive_to_bucket_subdir]}"
      end
      
      desc <<-DESC
        Restore the MySQL database from the S3 bucket specified by \
        ec2onrails_config[:restore_from_bucket]. The archive filename is \
        expected to be the default, "mysqldump.sql.gz".
      DESC
      task :restore, :roles => :db do
        run "/usr/local/ec2onrails/bin/restore_app_db.rb --bucket #{cfg[:restore_from_bucket]} --dir #{cfg[:restore_from_bucket_subdir]}"
      end
      
      desc <<-DESC
        [internal] Initialize the default backup folder on S3 (i.e. do a full
        backup of the newly-created db so the automatic incremental backups 
        make sense).  NOTE: Only of use if you do not have ebs enabled
      DESC
      task :init_backup, :roles => :db do
        server.allow_sudo do
          sudo "/usr/local/ec2onrails/bin/backup_app_db.rb --reset"
        end
      end
      
      # do NOT run if the flag does not exist.  This is placed by a startup script
      # and it is only run on the first-startup.  This means after the db has been
      # optimized, this task will not work again.  
      #
      # Of course you can overload it or call the file directly
      task :optimize, :roles => :db do
        if !quiet_capture("test -e /tmp/optimize_db_flag && echo 'file exists'").empty?
          begin
            sudo "/usr/local/ec2onrails/bin/optimize_mysql.rb"
          ensure
            sudo "rm -rf /tmp/optimize_db_flag" #remove so we cannot run again
          end
        else
          puts "skipping as it looks like this task has already been run"
        end
      end
      
    end
    
    namespace :server do
      desc <<-DESC
        Tell the servers what roles they are in. This configures them with \
        the appropriate settings for each role, and starts and/or stops the \
        relevant services.
      DESC
      task :set_roles do
        # TODO generate this based on the roles that actually exist so arbitrary new ones can be added
        roles = {
          :web        => hostnames_for_role(:web),
          :app        => hostnames_for_role(:app),
          :db_primary => hostnames_for_role(:db, :primary => true),
          # doing th ebelow can cause errors elsewhere unless :db is populated.
          # :db         => hostnames_for_role(:db),
          :memcache   => hostnames_for_role(:memcache)
        }
        roles_yml = YAML::dump(roles)
        put roles_yml, "/tmp/roles.yml"
        server.allow_sudo do
          sudo "cp /tmp/roles.yml /etc/ec2onrails"
          #we want everyone to be able to read to it
          sudo "chmod a+r /etc/ec2onrails/roles.yml"
          sudo "/usr/local/ec2onrails/bin/set_roles.rb"
        end
      end
      
      task :init_services do
        server.allow_sudo do
          #lets pick up the new configuration files
          sudo "/usr/local/ec2onrails/bin/init_services.rb"
        end
      end
      
      task :setup_web_proxy, :roles => :web do
        sudo "/usr/local/ec2onrails/bin/setup_web_proxy.rb --mode #{cfg[:web_proxy_server].to_s}"
      end

      desc <<-DESC
        Change the default value of RAILS_ENV on the server. Technically
        this changes the server's mongrel config to use a different value
        for "environment". The value is specified in :rails_env.
        Be sure to do deploy:restart after this.
      DESC
      task :set_rails_env do
        rails_env = fetch(:rails_env, "production")
        sudo "/usr/local/ec2onrails/bin/set_rails_env #{rails_env}"
      end
      
      desc <<-DESC
        Upgrade to the newest versions of all Ubuntu packages.
      DESC
      task :upgrade_packages do
        sudo "aptitude -q update"
        sudo "sh -c 'export DEBIAN_FRONTEND=noninteractive; aptitude -q -y safe-upgrade'"
      end
      
      desc <<-DESC
        Upgrade to the newest versions of all rubygems.
      DESC
      task :upgrade_gems do
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
        require configuration either set ec2onrails_config[:interactive_packages] \
        like you would for ec2onrails_config[:packages] (we'll flood the server \
        with 'Y' inputs), or log in as 'root' and run \
        'dpkg-reconfigure packagename' or replace the package's config files \
        using the 'ec2onrails:server:deploy_files' task.
      DESC
      task :install_packages do
        sudo "aptitude -q update"
        if cfg[:packages] && cfg[:packages].any?
          sudo "sh -c 'export DEBIAN_FRONTEND=noninteractive; aptitude -q -y install #{cfg[:packages].join(' ')}'"
        end
        if cfg[:interactive_packages] && cfg[:interactive_packages].any?
          # sudo "aptitude install #{cfg[:interactive_packages].join(' ')}", {:env => {'DEBIAN_FRONTEND' => 'readline'} }
          #trying to pick WHEN to send a Y is a bit tricky...it totally depends on the 
          #interactive package you want to install.  FLOODING it with 'Y'... but not sure how
          #'correct' or robust this is
          cmd = "sudo sh -c 'export DEBIAN_FRONTEND=readline; aptitude -y -q install #{cfg[:interactive_packages].join(' ')}'"
          run(cmd) do |channel, stream, data|
              channel.send_data "Y\n"
          end
        end
      end

      desc <<-DESC
        Provide extra security measures.  Set ec2onrails_config[:harden_server] = true \
        to allow the hardening of the server.
        These security measures are those which can make initial setup and playing around
        with Ec2onRails tricky.  For example, you can be logged out of your server forever
      DESC
      task :harden_server do
        #NOTES: for those security features that will get in the way of ease-of-use
        #       hook them in here
        # Like encrypting the mnt directory
        # http://groups.google.com/group/ec2ubuntu/web/encrypting-mnt-using-cryptsetup-on-ubuntu-7-10-gutsy-on-amazon-ec2
        if cfg[:harden_server]
          #lets install some extra packages:
          # denyhosts: sshd security tool.  config file is already installed... 
          #
          security_pkgs = %w{denyhosts}
          sudo "sh -c 'export DEBIAN_FRONTEND=noninteractive; aptitude -q -y install #{security_pkgs.join(' ')}'"
        end
      end
      
      desc <<-DESC
        Install extra rubygems. Set ec2onrails_config[:rubygems], it should \
        be with an array of strings.
      DESC
      task :install_gems do
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
      
      task :run_rails_rake_gems_install do
        #if running under Rails 2.1, lets trigger 'rake gems:install', but in such a way
        #so it fails gracefully if running rails < 2.1
        # ALSO, this might be the first time rake is run, and running it as sudo means that 
        # if any plugins are loaded and create directories... like what image_science does for 
        # ruby_inline, then the dirs will be created as root.  so trigger the rails loading
        # very quickly before the sudo is called
        # run "cd #{release_path} && rake RAILS_ENV=#{rails_env} -T 1>/dev/null && sudo rake RAILS_ENV=#{rails_env} gems:install"
        ec2onrails.server.allow_sudo do
          output = quiet_capture "cd #{release_path} && rake RAILS_ENV=#{rails_env} db:version 2>&1 1>/dev/null || sudo rake RAILS_ENV=#{rails_env} gems:install"
          puts output
        end
      end
      
      desc <<-DESC
        Add extra gem sources to rubygems (to able to fetch gems from for example gems.github.com).
        Set ec2onrails_config[:rubygems_sources], it should be with an array of strings.
      DESC
      task :add_gem_sources do
        if cfg[:rubygems_sources]
          cfg[:rubygems_sources].each do |gem_source|
            sudo "gem sources -a #{gem_source}"
          end
        end
      end
      
      desc <<-DESC
        A convenience task to upgrade existing packages and gems and install \
        specified new ones.
      DESC
      task :upgrade_and_install_all do
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
      task :set_timezone do
        if cfg[:timezone]
          ec2onrails.server.allow_sudo do
            sudo "bash -c 'echo #{cfg[:timezone]} > /etc/timezone'"
            sudo "cp /usr/share/zoneinfo/#{cfg[:timezone]} /etc/localtime"
          end
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
      task :deploy_files do
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
            sudo "rm -f #{remote_file}"
          end
        end
      end
      
      desc <<-DESC
        Restart a set of services. Set ec2onrails_config[:services_to_restart] \
        to an array of strings. It's assumed that each service has a script \
        in /etc/init.d
      DESC
      task :restart_services do
        if cfg[:services_to_restart] && cfg[:services_to_restart].any?
          cfg[:services_to_restart].each do |service|
            run_init_script(service, "restart")
          end
        end
      end
      
      desc <<-DESC
        Set the email address that mail to the app user forwards to.
      DESC
      task :set_mail_forward_address do
        run "echo '#{cfg[:mail_forward_address]}' >> /home/app/.forward" if cfg[:mail_forward_address]
        # put cfg[:admin_mail_forward_address], "/home/admin/.forward" if cfg[:admin_mail_forward_address]
      end

      desc <<-DESC
        Enable ssl for the web server. The SSL cert file should be in
        /etc/ssl/certs/default.pem and the SSL key file should be in
        /etc/ssl/private/default.key (use the deploy_files task).
      DESC
      task :enable_ssl, :roles => :web do
        #TODO: enable for nginx
        sudo "a2enmod ssl"
        sudo "a2enmod headers" # the headers module is necessary to forward a header so that rails can detect it is handling an SSL connection.  NPG 7/11/08
        sudo "a2ensite default-ssl"
        run_init_script("web_proxy", "restart")
      end
      
      desc <<-DESC
        Restrict the main user's sudo access.
        Defaults the user to only be able to \
        sudo to god
      DESC
      task :restrict_sudo_access do
        old_user = fetch(:user)
        begin
          set :user, 'root'
          sessions.clear #clear out sessions cache..... this way the ssh connections are reinitialized
          sudo "cp -f /etc/sudoers.restricted_access /etc/sudoers"
          # run "ln -sf /etc/sudoers.restricted_access /etc/sudoers"
        ensure
          set :user, old_user
          sessions.clear
        end
      end

      desc <<-DESC
        Grant *FULL* sudo access to the main user.
      DESC
      task :grant_sudo_access do
        allow_sudo
      end

      @within_sudo = 0
      def allow_sudo
        begin
          @within_sudo += 1
          old_user = fetch(:user)
          if @within_sudo > 1
            yield if block_given?
            true
          elsif capture("ls -l /etc/sudoers /etc/sudoers.full_access | awk '{print $5}'").split.uniq.size == 1
            yield if block_given?
            false
          else
            begin
              # need to cheet and temporarily set the user to ROOT so we
              # can (re)grant full sudo access.  
              # we can do this because the root and app user have the same
              # ssh login preferences....
              #
              # TODO:
              #   do not escalate priv. to root...use another user like 'admin' that has full sudo access
              set :user, 'root'
              sessions.clear #clear out sessions cache..... this way the ssh connections are reinitialized
              run "cp -f /etc/sudoers.full_access /etc/sudoers"
              set :user, old_user
              sessions.clear 
              yield if block_given?
            ensure
              server.restrict_sudo_access if block_given?
              set :user, old_user
              sessions.clear
              true
            end
          end
        ensure
          @within_sudo -= 1
        end
      end
    end
    
  end
end

