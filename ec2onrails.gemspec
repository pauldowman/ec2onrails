# This file is auto-generated, do not edit.
# Edit echoe_config.rb and then run 'rake ec2onrails_gem'
# 
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ec2onrails}
  s.version = "0.9.10.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Dowman, Adam Greene"]
  s.date = %q{2009-06-29}
  s.description = %q{Client-side libraries (Capistrano tasks) for managing and  deploying to EC2 on Rails servers.}
  s.email = %q{paul@pauldowman.com}
  s.extra_rdoc_files = ["CHANGELOG", "lib/ec2onrails/capistrano_utils.rb", "lib/ec2onrails/recipes/db.rb", "lib/ec2onrails/recipes/deploy.rb", "lib/ec2onrails/recipes/server.rb", "lib/ec2onrails/recipes.rb", "lib/ec2onrails/version.rb", "lib/ec2onrails.rb", "README.textile"]
  s.files = ["CHANGELOG", "COPYING", "echoe_config.rb", "examples/Capfile", "examples/deploy.rb", "examples/s3.yml", "lib/ec2onrails/capistrano_utils.rb", "lib/ec2onrails/recipes/db.rb", "lib/ec2onrails/recipes/deploy.rb", "lib/ec2onrails/recipes/server.rb", "lib/ec2onrails/recipes.rb", "lib/ec2onrails/version.rb", "lib/ec2onrails.rb", "Manifest", "Rakefile", "README.textile", "server/build", "server/files/etc/aliases", "server/files/etc/cron.d/ec2onrails", "server/files/etc/cron.daily/app", "server/files/etc/cron.daily/logrotate_post", "server/files/etc/cron.hourly/app", "server/files/etc/cron.monthly/app", "server/files/etc/cron.weekly/app", "server/files/etc/denyhosts.conf", "server/files/etc/dpkg/dpkg.cfg", "server/files/etc/ec2onrails/rails_env", "server/files/etc/ec2onrails/roles.yml", "server/files/etc/environment", "server/files/etc/event.d/god", "server/files/etc/god/db_primary.god", "server/files/etc/god/dkim_filter.god", "server/files/etc/god/examples/have_god_daemonize.god", "server/files/etc/god/master.conf", "server/files/etc/god/memcache.god", "server/files/etc/god/notifications.god", "server/files/etc/god/system.god", "server/files/etc/god/web.god", "server/files/etc/init.d/ec2-every-startup", "server/files/etc/init.d/ec2-first-startup", "server/files/etc/init.d/nginx", "server/files/etc/logrotate.d/mongrel", "server/files/etc/logrotate.d/nginx", "server/files/etc/memcached.conf", "server/files/etc/motd.tail", "server/files/etc/mysql/my.cnf", "server/files/etc/nginx/custom.conf", "server/files/etc/nginx/nginx.conf.erb", "server/files/etc/postfix/main.cf", "server/files/etc/README", "server/files/etc/ssh/sshd_config", "server/files/etc/sudoers", "server/files/etc/syslog.conf", "server/files/usr/local/ec2onrails/bin/archive_file", "server/files/usr/local/ec2onrails/bin/backup_app_db", "server/files/usr/local/ec2onrails/bin/backup_dir", "server/files/usr/local/ec2onrails/bin/ec2_meta_data", "server/files/usr/local/ec2onrails/bin/exec_runner", "server/files/usr/local/ec2onrails/bin/init_services", "server/files/usr/local/ec2onrails/bin/install_system_files", "server/files/usr/local/ec2onrails/bin/optimize_mysql", "server/files/usr/local/ec2onrails/bin/public-hostname", "server/files/usr/local/ec2onrails/bin/rails_env", "server/files/usr/local/ec2onrails/bin/rebundle", "server/files/usr/local/ec2onrails/bin/restore_app_db", "server/files/usr/local/ec2onrails/bin/set_rails_env", "server/files/usr/local/ec2onrails/bin/set_roles", "server/files/usr/local/ec2onrails/bin/uninstall_system_files", "server/files/usr/local/ec2onrails/config", "server/files/usr/local/ec2onrails/COPYING", "server/files/usr/local/ec2onrails/lib/aws_helper.rb", "server/files/usr/local/ec2onrails/lib/god_helper.rb", "server/files/usr/local/ec2onrails/lib/mysql_helper.rb", "server/files/usr/local/ec2onrails/lib/roles_helper.rb", "server/files/usr/local/ec2onrails/lib/s3_helper.rb", "server/files/usr/local/ec2onrails/lib/system_files_helper.rb", "server/files/usr/local/ec2onrails/lib/system_files_manifest.rb", "server/files/usr/local/ec2onrails/lib/utils.rb", "server/files/usr/local/ec2onrails/lib/vendor/ini.rb", "server/files/usr/local/ec2onrails/startup-scripts/every-startup/create-mysqld-pid-dir", "server/files/usr/local/ec2onrails/startup-scripts/every-startup/README", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/create-dirs", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/generate-default-web-cert-and-key", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/get-hostname", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/misc", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/prepare-mysql-data-dir", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/README", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/setup-credentials", "server/files/usr/local/ec2onrails/startup-scripts/first-startup/setup-file-permissions", "server/rakefile-wrapper", "server/rakefile.rb", "test/autobench.conf", "test/spec/lib/s3_helper_spec.rb", "test/spec/lib/s3_old.yml", "test/spec/lib/system_files_manifest_spec.rb", "test/spec/test_files/system_files1/_manifest", "test/spec/test_files/system_files1/test1", "test/spec/test_files/system_files1/test2", "test/spec/test_files/system_files1/testfolder/test3", "test/spec/test_files/system_files2/_manifest", "test/spec/test_files/system_files2/test1", "test/spec/test_files/system_files2/test2", "test/spec/test_files/system_files2/testfolder/test3", "test/spec/test_files/test2", "test/test_app/app/controllers/application_controller.rb", "test/test_app/app/controllers/db_fast_controller.rb", "test/test_app/app/controllers/fast_controller.rb", "test/test_app/app/controllers/slow_controller.rb", "test/test_app/app/controllers/very_slow_controller.rb", "test/test_app/app/helpers/application_helper.rb", "test/test_app/Capfile", "test/test_app/config/boot.rb", "test/test_app/config/database.yml", "test/test_app/config/deploy.rb", "test/test_app/config/ec2onrails/config.rb", "test/test_app/config/environment.rb", "test/test_app/config/environments/development.rb", "test/test_app/config/environments/production.rb", "test/test_app/config/environments/test.rb", "test/test_app/config/initializers/backtrace_silencers.rb", "test/test_app/config/initializers/inflections.rb", "test/test_app/config/initializers/mime_types.rb", "test/test_app/config/initializers/new_rails_defaults.rb", "test/test_app/config/initializers/session_store.rb", "test/test_app/config/locales/en.yml", "test/test_app/config/routes.rb", "test/test_app/db/development.sqlite3", "test/test_app/doc/README_FOR_APP", "test/test_app/public/404.html", "test/test_app/public/422.html", "test/test_app/public/500.html", "test/test_app/public/favicon.ico", "test/test_app/public/images/rails.png", "test/test_app/public/index.html", "test/test_app/public/javascripts/application.js", "test/test_app/public/javascripts/controls.js", "test/test_app/public/javascripts/dragdrop.js", "test/test_app/public/javascripts/effects.js", "test/test_app/public/javascripts/prototype.js", "test/test_app/public/robots.txt", "test/test_app/Rakefile", "test/test_app/README", "test/test_app/script/about", "test/test_app/script/console", "test/test_app/script/dbconsole", "test/test_app/script/destroy", "test/test_app/script/generate", "test/test_app/script/performance/benchmarker", "test/test_app/script/performance/profiler", "test/test_app/script/plugin", "test/test_app/script/runner", "test/test_app/script/server", "test/test_app/test/performance/browsing_test.rb", "test/test_app/test/test_helper.rb", "TODO", "ec2onrails.gemspec"]
  s.has_rdoc = true
  s.homepage = %q{http://ec2onrails.rubyforge.org}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Ec2onrails", "--main", "README.textile"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ec2onrails}
  s.rubygems_version = %q{1.3.2}
  s.summary = %q{Client-side libraries (Capistrano tasks) for managing and  deploying to EC2 on Rails servers.}
  s.test_files = ["test/test_app/test/performance/browsing_test.rb", "test/test_app/test/test_helper.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, [">= 2.4.3"])
      s.add_runtime_dependency(%q<archive-tar-minitar>, [">= 0.5.2"])
      s.add_runtime_dependency(%q<optiflag>, [">= 0.6.5"])
      s.add_development_dependency(%q<rake>, [">= 0.7.1"])
    else
      s.add_dependency(%q<capistrano>, [">= 2.4.3"])
      s.add_dependency(%q<archive-tar-minitar>, [">= 0.5.2"])
      s.add_dependency(%q<optiflag>, [">= 0.6.5"])
      s.add_dependency(%q<rake>, [">= 0.7.1"])
    end
  else
    s.add_dependency(%q<capistrano>, [">= 2.4.3"])
    s.add_dependency(%q<archive-tar-minitar>, [">= 0.5.2"])
    s.add_dependency(%q<optiflag>, [">= 0.6.5"])
    s.add_dependency(%q<rake>, [">= 0.7.1"])
  end
end
