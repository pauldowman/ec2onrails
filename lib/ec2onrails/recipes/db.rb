Capistrano::Configuration.instance.load do
  cfg = ec2onrails_config
  
  namespace :ec2onrails do
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
        sleep(15) # make sure the db has some time to start up!
        
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
          zone = quiet_capture("/usr/local/ec2onrails/bin/ec2_meta_data -key 'placement/availability-zone'")
          instance_id = quiet_capture("/usr/local/ec2onrails/bin/ec2_meta_data -key 'instance-id'")

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
      			while !system( "ec2-describe-volumes | grep #{vol_id} | grep attached" )
      				puts "Waiting for #{vol_id} to be attached..."
      				sleep 1            
      			end
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
              start_stop_db = god_status['db_primary']['mysql'] == 'up'
              if start_stop_db
                stop
                puts "Waiting for mysql to stop"
                sleep(10)
              end
              quiet_capture("sudo umount #{mysql_dir_root}") #unmount if need to
              puts "Checking if the filesystem needs to be created (if you created #{vol_id} yourself)"
              existing = quiet_capture( "mkfs.xfs /dev/sdh", :via => 'sudo' ).match( /existing filesystem/ )
              sudo "xfs_check #{block_mnt}"
              # Restart the db if it 
              start if start_stop_db && existing
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
            sudo "touch /etc/ec2onrails/ebs_info.yml"
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
        sudo "god start db_primary"
      end

      task :stop, :roles => :db do
        sudo "god stop db_primary"
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
          begin
            run %{mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('#{cfg[:mysql_root_password]}') WHERE User='root'; FLUSH PRIVILEGES;"}
          rescue Exception => e
            #most likely because the password was already set
            #in that case this is fine to swallow the error because the task is 'set' db password, not reset it.... we would have to know
            #what the old root password was
          end
        end
      end
      
      desc <<-DESC
        Dump the MySQL database to ebs (if enabled) or the S3 bucket specified by \
        ec2onrails_config[:archive_to_bucket]. The filename will be \
        "database-archive/<timestamp>/dump.sql.gz".
      DESC
      task :archive, :roles => :db do
        run "/usr/local/ec2onrails/bin/backup_app_db --bucket #{cfg[:archive_to_bucket]} --dir #{cfg[:archive_to_bucket_subdir]}"
      end
      
      desc <<-DESC
        Restore the MySQL database from the S3 bucket specified by \
        ec2onrails_config[:restore_from_bucket]. The archive filename is \
        expected to be the default, "mysqldump.sql.gz".
      DESC
      task :restore, :roles => :db do
        run "/usr/local/ec2onrails/bin/restore_app_db --bucket #{cfg[:restore_from_bucket]} --dir #{cfg[:restore_from_bucket_subdir]}"
      end
      
      desc <<-DESC
        [internal] Initialize the default backup folder on S3 (i.e. do a full
        backup of the newly-created db so the automatic incremental backups 
        make sense).  NOTE: Only of use if you do not have ebs enabled
      DESC
      task :init_backup, :roles => :db do
        server.allow_sudo do
          sudo "/usr/local/ec2onrails/bin/backup_app_db --reset"
        end
      end
      
      # do NOT run if the flag does not exist.  This is placed by a startup script
      # and it is only run on the first-startup.  This means after the db has been
      # optimized, this task will not work again.  
      #
      # Of course you can overload it or call the file directly
      task :optimize, :roles => :db do
        if !quiet_capture("test -e /tmp/optimize_db_flag && echo 'file exists'").empty?
          ec2onrails.server.allow_sudo do
            begin
              sudo "/usr/local/ec2onrails/bin/optimize_mysql"
            ensure
              sudo "rm -rf /tmp/optimize_db_flag" #remove so we cannot run again
            end
          end
        else
          puts "skipping as it looks like this task has already been run"
        end
      end
      
    end

  end
end

