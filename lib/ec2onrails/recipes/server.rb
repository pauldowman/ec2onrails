Capistrano::Configuration.instance(:must_exist).load do
  cfg = ec2onrails_config
  
  namespace :ec2onrails do
    namespace :server do
      desc <<-DESC
        Tell the servers what roles they are in. This configures them with \
        the appropriate settings for each role, and starts and/or stops the \
        relevant services.
      DESC
      task :set_roles do
        # TODO generate this based on the roles that actually exist so arbitrary new ones can be added
        # user_defined_roles = roles
        # roles.each do |k,v|
        #   puts "#{k}, #{v.servers.first.options.inspect}"
        #   {:primary=>true}
        # 
        # end
        # 
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
      
      task :setup_elastic_ip, :roles => :web do
        #TODO: for elastic IP
        #  * make  sure the hostname is reset on the web server
        #  * make sure the roles.yml file is updated for ALL servers....
        vol_id = ENV['ELASTIC_IP'] || servers.first.options[:elastic_ip]
        ec2onrails.server.allow_sudo do
          server.set_roles
        end
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
        ec2onrails.server.allow_sudo do
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
      end
      
      task :configure_firewall do
        # TODO
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
          
          #lets setup dkim
          setup_email_signing
        end
      end
      
      #based on the recipe here (but which is missing a few key steps!)
      #http://www.howtoforge.com/quick-and-easy-setup-for-domainkeys-using-ubuntu-postfix-and-dkim-filter
      desc <<-DESC
        enables dkim signing of outgoing msgs.  This helps with fightint spam.
        You'll have to update your dns records to take advantage of this, but we'll
        help you out with that 
        NOTE: set ec2onrails_config[:service_domain] = 'yourdomain.com' before running this task
      DESC
      task :setup_email_signing, :roles => :app do
        ec2onrails.server.allow_sudo do      
          if cfg[:service_domain].nil? || cfg[:service_domain].empty?
            raise "ERROR: missing the :service_domain key.  Please set that in your deploy script if you would like to use this task."
          end

          domain = cfg[:service_domain]
          postmaster_email = "postmaster@#{domain}"

          #make the selector something that will help us roll over and expire the old key next year
          selector = "mail#{Time.now.year.to_s[-2..-1]}"  #ie, mail09

          sudo "sh -c 'export DEBIAN_FRONTEND=noninteractive; aptitude -q -y install postfix dkim-filter'"
          #do NOT change the size of the key; making it longer can cause problems with some of the dkim implementations

          keys_exist = File.exist?("config/mail/dkim/dkim_#{selector}.private.key") && File.exist?("config/mail/dkim/dkim_#{selector}.public.key")

          unless keys_exist
            #lets make them!
            cmds = <<-CMDS
    mkdir -p config/mail/dkim;
    cd config/mail/dkim;
    openssl genrsa -out dkim_#{selector}.private.key 1024;
    openssl rsa -in dkim_#{selector}.private.key -out dkim_#{selector}.public.key -pubout -outform PEM
    CMDS
            system cmds
          end

          pub_key = File.read("config/mail/dkim/dkim_#{selector}.public.key")
          pub_key = pub_key.split("\n")[1..-2].join(' ')

          #lets get the private and public keys up to the server
          put File.read("config/mail/dkim/dkim_#{selector}.private.key"), "/tmp/dkim_#{selector}.private.key"
          put File.read("config/mail/dkim/dkim_#{selector}.public.key"), "/tmp/dkim_#{selector}.public.key"
          sudo "mkdir -p /var/dkim-filter"
          sudo "mv /tmp/dkim_#{selector}.p*.key /var/dkim-filter/."

          #saw a note that Canonicalization relaxed was helpful for rails applications...
          #haven't tested that yet
          dkim_filter_conf = <<-SCRIPT 
    # Log to syslog
      Syslog      yes

    # Sign for example.com with key in /etc/mail/dkim.key using
      Domain      #{domain}		
      KeyFile     /var/dkim-filter/dkim_#{selector}.private.key
      Selector    #{selector} 

    # Common settings. See dkim-filter.conf(5) for more information.
      AutoRestart       no
      Background        yes
      SubDomains        no
      Canonicalization  relaxed
    SCRIPT

          put dkim_filter_conf, "/tmp/dkim-filter.conf.tmp"
          sudo "mv /etc/dkim-filter.conf /etc/dkim-filter.conf.orig" 
          sudo "mv /tmp/dkim-filter.conf.tmp /etc/dkim-filter.conf" 
          cmds = <<-CMDS
    sudo postconf -e 'myhostname = #{domain}';
    sudo postconf -e 'mydomain = #{domain}';
    sudo postconf -e 'myorigin = $mydomain';
    sudo postconf -e 'biff = no';
    sudo postconf -e 'alias_maps = hash:/etc/aliases';
    sudo postconf -e 'alias_database = hash:/etc/aliases';
    sudo postconf -e 'mydestination = localdomain, localhost, localhost.localdomain, localhost';
    sudo postconf -e 'mynetworks = 127.0.0.0/8';
    sudo postconf -e 'smtpd_milters = inet:localhost:8891';
    sudo postconf -e 'non_smtpd_milters = inet:localhost:8891';
    sudo postconf -e 'milter_protocol = 2';
    sudo postconf -e 'milter_default_action = accept'
    CMDS
          sudo cmds

          #lets lock it down
          sudo "chown -R dkim-filter:dkim-filter /var/dkim-filter"
          sudo "chmod 600 /var/dkim-filter/*"

          puts "*" * 80
          puts "NOTE: you need to do a few things"
          puts "  * created public and private DKIM keys to config/mail/dkim_#{selector}.*.key" unless keys_exist
          puts "\n"
          msg = <<-MSG
      * Enter these *TWO* records into your DNS record:
          #{selector}._domainkey.#{domain} IN TXT 'k=rsa; t=y; p=#{pub_key}'
          _domainkey.#{domain} IN TXT 't=y; o=~; r=#{postmaster_email}'

    I would recommend signing into your ec2 instance and running some test emails.  Gmail is very fast in updating their records, but yahoo (as of this writing) is slow and inconsistent.  But you can run a command like this to various email address to see how it works:

    echo 'something searchable so you can find it in your spam filter!  did dkim work?' | mail -s "my dkim email; lets see how it went" adam@someservice.com


    NOTE: in the near future, when things are looking good, if you take away the 't=y; ' from the above two records, it tells the email services that you are no longer testing the service and to treat your signings with tough love.


    MSG
          puts msg

          #putting this below because sometimes restarting the dkim filter fails
          sudo "/etc/init.d/dkim-filter restart 2>&1"
          sudo "/etc/init.d/postfix restart 2>&1"
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