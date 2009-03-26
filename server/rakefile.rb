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


# This script is meant to be run by rakefile-wrapper, which is run by
# Eric Hammond's Ubuntu build script: http://alestic.com/
# See the README file for details

require "rake/clean"
require 'yaml'
require 'erb'
require "#{File.dirname(__FILE__)}/../lib/ec2onrails/version"

if `whoami`.strip != 'root'
  raise "Sorry, this buildfile must be run as root."
end

# package notes:
# * aptitude:       much better package installation system, especially around 
#                   upgrades and package dependencies
# * gcc:            libraries needed to compile c/c++ files from source
# * libmysqlclient-dev : provide mysqlclient-dev libs, needed for DataObject gems
# * nano/vim/less:  simle file editors and viewer
# * git-core:       because we are all using git now, aren't we?
# * xfsprogs:       help with freezing and resizing of persistent volumes
# 
  
@packages = %w(
  adduser
  aptitude
  bison
  ca-certificates
  cron
  curl
  flex
  gcc
  git-core
  irb
  less
  libmysql-ruby
  libpcre3-dev
  libssl-dev
  libyaml-ruby
  libzlib-ruby
  logrotate
  make
  mailx
  memcached
  mysql-client
  mysql-server
  nano
  openssh-server
  postfix
  rdoc
  ri
  rsync
  ruby-full
  subversion
  sysstat
  unzip
  vim
  wget
  xfsprogs
)

# HACK: some packages just fail with apt-get but work fine
#       with aptitude.  These generally are virtual packages
@aptitude_packages = %w(
  libmysqlclient-dev
)

# NOTE: the amazon-ec2 gem is now at github, maintained by
#       grempe-amazon-ec2.  Will move back to regular amazon-ec2
#       gem if/when he cuts a new release with volume and snapshot
#       support included
@rubygems = [
  "grempe-amazon-ec2",
  "aws-s3",
  "god",
  "RubyInline",
  "memcache-client",
  "mongrel",
  "mongrel_cluster",
  "optiflag",
  "rails",
  "rails -v '~> 2.3.2'",
  "rails -v '~> 2.2.2'",
  "rails -v '~> 2.1.2'",
  "rails -v '~> 2.0.5'",
  "rails -v '~> 1.2.6'",
  "rake"
]

@build_root = "/mnt/build"
@fs_dir = "#{@build_root}/ubuntu"

@version = [Ec2onrails::VERSION::STRING]

task :default => :configure

desc "Removes all build files"
task :clean_all do |t|
  puts "Unmounting proc and dev from #{@build_root}..."
  run "umount #{@build_root}/ubuntu/proc", true
  run "umount #{@build_root}/ubuntu/dev", true

  puts "Removing #{@build_root}..."
  rm_rf @build_root
end

desc "Use apt-get to install required packages inside the image's filesystem"
task :install_packages do |t|
  unless_completed(t) do
    ENV['DEBIAN_FRONTEND'] = 'noninteractive'
    ENV['LANG'] = ''
    run_chroot "apt-get update"
    run_chroot "apt-get install -y #{@packages.join(' ')}"
    run_chroot "apt-get autoremove -y"
    run_chroot "apt-get clean"
    
    #lets run the aptitude-only packages
    run_chroot "aptitude install -y #{@aptitude_packages.join(' ')}"
    run_chroot "aptitude clean"
  end
end

desc "Install required ruby gems inside the image's filesystem"
task :install_gems => [:install_packages] do |t|
  unless_completed(t) do
    run_chroot "sh -c 'cd /tmp && wget -q http://rubyforge.org/frs/download.php/45905/rubygems-1.3.1.tgz && tar zxf rubygems-1.3.1.tgz'"
    run_chroot "sh -c 'cd /tmp/rubygems-1.3.1 && ruby setup.rb'"
    run_chroot "ln -sf /usr/bin/gem1.8 /usr/bin/gem"
    #NOTE: this will update to rubygems 1.3 and beyond... 
    #      this was broken in rubygems 1.1 and 1.2, but it looks like they fixed it
    run_chroot "gem update --system --no-rdoc --no-ri"
    run_chroot "gem update --no-rdoc --no-ri"
    run_chroot "gem sources -a http://gems.github.com"
    @rubygems.each do |g|
      run_chroot "gem install #{g} --no-rdoc --no-ri"
    end
  end
end

desc "Install nginx from source"
task :install_nginx => [:install_packages] do |t|
  nginx_version = "nginx-0.6.35"
  nginx_tar = "#{nginx_version}.tar.gz"

  nginx_img = "http://sysoev.ru/nginx/#{nginx_tar}"
  fair_bal_img = "http://github.com/gnosek/nginx-upstream-fair/tarball/master"
  src_dir = "/tmp/src/nginx"
  # Make sure the dir is created but empty...lets start afresh
  run_chroot "mkdir -p -m 755 #{src_dir}/ &&  rm -rf #{src_dir}/*" 
  run_chroot "mkdir -p -m 755 #{src_dir}/modules/nginx-upstream-fair"
  run_chroot "cd #{src_dir} && wget -q #{nginx_img} && tar -xzf #{nginx_tar}"
  
  run_chroot "cd #{src_dir}/modules && \
       wget -q #{fair_bal_img} && \
       tar -xzf *nginx-upstream-fair*.tar.gz -o -C ./nginx-upstream-fair && \
       mv nginx-upstream-fair/*/* nginx-upstream-fair/."
  
  run_chroot "cd #{src_dir}/#{nginx_version} && \
       ./configure \
         --sbin-path=/usr/sbin \
         --conf-path=/etc/nginx/nginx.conf \
         --pid-path=/var/run/nginx.pid \
         --with-http_ssl_module \
         --with-http_stub_status_module \
         --add-module=#{src_dir}/modules/nginx-upstream-fair && \
       make && \
       make install"

   # run_chroot "ln -sf /usr/local/nginx/sbin/nginx /usr/sbin/nginx"
   # run_chroot "ln -sf /usr/local/nginx/conf /etc/nginx"
end

desc "Install Ubuntu packages, download and compile other software, and install gems"
task :install_software => [:install_gems, :install_packages, :install_nginx]

desc "Configure the image"
task :configure => [:install_software] do |t|
  unless_completed(t) do
    sh("cp -r files/* #{@fs_dir}")
    replace("#{@fs_dir}/etc/motd.tail", /!!VERSION!!/, "Version #{@version}")

    run_chroot "/usr/sbin/adduser --group nginx --disabled-login --no-create-home nginx"
        
    run_chroot "/usr/sbin/adduser --gecos ',,,' --disabled-password app"

    run_chroot "cp /root/.gemrc /home/app" # so the app user also has access to gems.github.com
        
    run "echo '. /usr/local/ec2onrails/config' >> #{@fs_dir}/root/.bashrc"
    run "echo '. /usr/local/ec2onrails/config' >> #{@fs_dir}/home/app/.bashrc"
    
    %w(mysql auth.log daemon.log kern.log mail.err mail.info mail.log mail.warn syslog user.log).each do |f|
      rm_rf "#{@fs_dir}/var/log/#{f}"
      run_chroot "ln -sf /mnt/log/#{f} /var/log/#{f}"
    end
    
    run "touch #{@fs_dir}/ec2onrails-first-boot"
    
    # TODO find out the most correct solution here, there seems to be a bug in
    # both feisty and gutsy where the dhcp daemon runs as dhcp but the dir
    # that it tries to write to is owned by root and not writable by others.
    # *** Do we still need this? The problem was constant messages in the syslog
    # after the first DHCP lease expired (after 12 hours or so).
    # We can probably assume Eric's base image does the right thing.
    run_chroot "chown -R dhcp /var/lib/dhcp3"
    
    #make sure that god is setup to reboot at startup
    run_chroot "update-rc.d god defaults 98"
  end
end

desc "This task is for deploying the contents of /files to a running server image to test config file changes without rebuilding."
task :deploy_files do |t|
  raise "need 'key' and 'host' env vars defined" unless ENV['key'] && ENV['host']
  run "rsync -rlvzcCp --rsh='ssh -l root -i #{ENV['key']}' files/ #{ENV['host']}:/"
end

##################

# Execute a given block and touch a stampfile. The block won't be run if the stampfile exists.
def unless_completed(task, &proc)
  stampfile = "#{@build_root}/#{task.name}.completed"
  unless File.exists?(stampfile)
    yield  
    touch stampfile
  end
end

def run_chroot(command, ignore_error = false)
  run "chroot '#{@fs_dir}' #{command}", ignore_error
end

def run(command, ignore_error = false)
  puts "*** #{command}" 
  result = system command
  raise("error: #{$?}") unless result || ignore_error
end

# def mount(type, mount_point)
#   unless mounted?(mount_point)
#     puts
#     puts "********** Mounting #{type} on #{mount_point}..."
#     puts
#     run "mount -t #{type} none #{mount_point}"
#   end
# end
# 
# def mounted?(mount_point)
#   mount_point_regex = mount_point.gsub(/\//, "\\/")
#   `mount`.select {|line| line.match(/#{mount_point_regex}/) }.any?
# end

def replace_line(file, newline, linenum)
  contents = File.open(file, 'r').readlines
  contents[linenum - 1] = newline
  File.open(file, 'w') do |f|
    contents.each {|line| f << line}
  end
end

def replace(file, pattern, text)
  contents = File.open(file, 'r').readlines
  contents.each do |line|
    line.gsub!(pattern, text)
  end
  File.open(file, 'w') do |f|
    contents.each {|line| f << line}
  end
end