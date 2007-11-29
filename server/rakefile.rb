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

require "rake/clean"
require 'yaml'
require 'erb'
#require 'EC2'
require "#{File.dirname(__FILE__)}/../gem/lib/ec2onrails/version"

@config_file = "config.yml"

@arch = ENV['arch'] || "32bit" # or use 'arch=64bit rake' on the command line

@packages = %w(
  adduser
  alien
  apache2
  aptitude
  ca-certificates
  cron
  curl
  gcc
  gnupg
  irb
  irb
  less
  libc6-xen
  libdbm-ruby
  libgdbm-ruby
  libmysql-ruby
  libopenssl-ruby
  libreadline-ruby
  libruby
  logrotate
  make
  man-db
  mysql-client
  mysql-server
  nano
  openssh-server
  php5
  php5-mysql
  postfix
  rake
  rdoc
  ri
  rsync
  ruby
  ruby1.8-dev
  rubygems
  subversion
  unzip
  vim
  wget
)

@rubygems = %w(
  amazon-ec2
  aws-s3
  mongrel
  mongrel_cluster
  optiflag
  rails
  rake
)

@arch_config = {
  "32bit" => {
    :name => "i386",
    :ubuntu_name => "i386",
    :modules_file => "modules-2.6.16-ec2.tgz",
    :modules_version => "2.6.16-xenU"
  },
  "64bit" => {
    :name => "x86_64",
    :ubuntu_name => "amd64",
    :modules_file => "ec2-modules-2.6.16.33-xenU-x86_64.tgz",
    :modules_version => "2.6.16.33-xenU"
  }
}


# I recommend using apt-cacher or apt-proxy. Change the url here and in files/etc/apt/sources.list
@deb_mirror = "" # Leave blank to use default
#@deb_mirror = "http://localhost:3142/archive.ubuntu.com/ubuntu/" # This is for a local apt-cacher instance


def arch_config
  @arch_config[@arch]
end

@output_dir = "output-#{arch_config[:name]}"
@fs_dir = "#{@output_dir}/fs"

@version = Ec2onrails::VERSION

task :default => :upload_bundle

desc "Removes all files inside the mounted filesystem except /proc and /lost+found"
task :clean_fs => :check_if_root do |t|
  to_delete = Dir.glob("#{@fs_dir}/*")
  to_delete.delete("#{@fs_dir}/lost+found")
  to_delete.delete("#{@fs_dir}/proc")
  rm_rf to_delete
end

desc "Removes all build products"
task :clean_all => [:check_if_root, :unmount_proc] do |t|
  rm_rf @output_dir
end

directory @output_dir

file @fs_dir => @output_dir do |t|
  mkdir_p "#{@fs_dir}/proc"
  mkdir_p "#{@fs_dir}/tmp"
end

desc "Mounts the proc filesystem"
task :mount_proc => [:check_if_root, @fs_dir] do |t|
  mount_point = "#{@fs_dir}/proc"
  unless mounted?(mount_point)
    puts
    puts "********** Mounting proc filesystem on #{mount_point}..."
    puts
    run "mount -t proc none #{mount_point}"
  end
end

task :unmount_proc => [:check_if_root, @fs_dir] do |t|
  if mounted?("#{@fs_dir}/proc")
    run "umount #{@fs_dir}/proc"
  end
end

desc "Download debootstrap"
task :install_debootstrap => @fs_dir do |t|
  unless_completed(t) do
    # We need devices.tar.gz from the .deb, it's not in the .tar.
    # But I want to use the .tar instead of the .deb because the .deb
    # puts files all over the filesystem
    run "cd #{@output_dir}; curl http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.3build1.tar.gz | tar zx"
    run "curl http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.3build1_all.deb > #{@output_dir}/deb"
    run "cd #{@output_dir}; ar x deb"
    run "cd #{@output_dir}; tar zxf data.tar.gz"
    cp "#{@output_dir}/usr/lib/debootstrap/devices.tar.gz", "#{@output_dir}/debootstrap-1.0.3build1"
    
    # We need to symlink scripts/ubuntu/gutsy to scripts/gutsy
    run "cd #{@output_dir}/debootstrap-1.0.3build1/scripts; ln -s ubuntu/gutsy"
  end
end

desc "Run debootstrap"
task :bootstrap => [:check_if_root, :install_debootstrap] do |t|
  unless_completed(t) do
    ENV['DEBOOTSTRAP_DIR'] = "#{@output_dir}/debootstrap-1.0.3build1"
    run "sh #{@output_dir}/debootstrap-1.0.3build1/debootstrap --arch #{arch_config[:ubuntu_name]} --include=gnupg,aptitude gutsy #{@fs_dir} #{@deb_mirror}"
  end
end

desc "Use aptitude to install required packages inside the image's filesystem"
task :install_packages => [:check_if_root, :bootstrap, :mount_proc] do |t|
  unless_completed(t) do
    FileUtils.cp 'files/etc/apt/sources.list', "#{@fs_dir}/etc/apt/sources.list"
    #ENV['DEBIAN_FRONTEND'] = 'noninteractive'
    ENV['LANG'] = ''
    run_chroot "aptitude update"
    run_chroot "aptitude dist-upgrade -y"
    run_chroot "aptitude install -y #{@packages.join(' ')}"
    
    # stop the daemons that were installed if they're running
    run_chroot "/etc/init.d/apache2 stop", true
    run_chroot "/etc/init.d/mysql stop", true
  end
end

desc "Download and unpack the Amazon kernel modules archive"
task :install_kernel_modules => [:check_if_root, :install_packages] do |t|
  unless_completed(t) do
    run "curl http://s3.amazonaws.com/ec2-downloads/#{arch_config[:modules_file]} | tar zx -C #{@fs_dir}"
    run_chroot "depmod -e -F /boot/System.map-#{arch_config[:modules_version]} #{arch_config[:modules_version]}"
  end
end

desc "Install required ruby gems inside the image's filesystem"
task :install_gems => [:check_if_root, :install_kernel_modules] do |t|
  unless_completed(t) do
    # TODO This part is way too interactive, try http://geminstaller.rubyforge.org
    run_chroot "gem update -y --no-rdoc --no-ri"
    run_chroot "gem install #{@rubygems.join(' ')} -y --no-rdoc --no-ri"
  end
end

desc "Configure the image"
task :configure => [:check_if_root, :install_gems] do |t|
  unless_completed(t) do
    sh("cp -r files/* #{@fs_dir}")
    replace("#{@fs_dir}/etc/motd.tail", /!!VERSION!!/, "Version #{@version::STRING}")
    
    run_chroot "localedef -i en_US -c -f UTF-8 en_US.UTF-8"
    run_chroot "a2enmod deflate"
    run_chroot "a2enmod proxy_balancer"
    run_chroot "a2enmod proxy_http"
    run_chroot "a2enmod rewrite"
    
    run_chroot "/usr/sbin/adduser --gecos ',,,' --disabled-password app"
    run_chroot "/usr/sbin/adduser --gecos ',,,' --disabled-password admin"
    
    run "echo '. /usr/local/ec2onrails/config' >> #{@fs_dir}/root/.profile"
    run "echo '. /usr/local/ec2onrails/config' >> #{@fs_dir}/home/app/.profile"
    
    (2..6).each { |n| rm_f "#{@fs_dir}/etc/event.d/tty#{n}" }
    
    %w(apache2 mysql auth.log daemon.log kern.log mail.err mail.info mail.log mail.warn syslog user.log).each do |f|
      rm_rf "#{@fs_dir}/var/log/#{f}"
      run_chroot "ln -sf /mnt/log/#{f} /var/log/#{f}"
    end
    
    touch "#{@fs_dir}/ec2onrails-first-boot"
    
    # TODO find out the most correct solution here, this seems to be a bug in
    # both feisty and gutsy where the dhcp daemon runs as dhcp but the dir
    # that it tries to write it is owned by root and not writable by others.
    run_chroot "chown -R dhcp /var/lib/dhcp3"
    
    run_chroot "aptitude clean"
  end
end

desc "Install Amazon's AMI tools"
task :install_ami_tools => [:check_if_root, :configure] do |t|
  unless_completed(t) do
    run "curl http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm > #{@fs_dir}/tmp/ec2-ami-tools.noarch.rpm"
    run_chroot "alien -i /tmp/ec2-ami-tools.noarch.rpm"
    
    # change shell from dash to bash to work around bug in ami tools
    # TODO should use "dpkg-reconfigure dash" instead...
    run_chroot "ln -sf /bin/bash /bin/sh"
    
    # modify ami tools src files as described in various posts on the aws forums
    # alternatively could just use patch command here
    
    file = "#{@fs_dir}/usr/lib/site_ruby/aes/amiutil/image.rb"
    new_line = "    exec( 'rsync -rlpgoDS ' + exclude + '--exclude /etc/udev/rules.d/70-persistent-net.rules ' + File::join( src, '*' ) + ' ' + dst )"
    replace_line(file, new_line, 161)
    
    file = "#{@fs_dir}/usr/lib/site_ruby/aes/amiutil/bundlevol.rb"
    new_line = "LOCAL_FS_TYPES = ['ext2', 'ext3', 'xfs', 'jfs', 'reiserfs', 'tmpfs']\n"
    replace_line(file, new_line, 81)
  end
end

desc "Load the user-specific config file that contains Amazon account info"
task :load_config do |t|
  unless File.exists?(@config_file)
    raise "Can't find #{@config_file}. Can't bundle EC2 image without your AWS account info."
  end
  config = YAML::load(ERB.new(File.read(@config_file)).result)
  @aws_account_id        = config['aws_account_id']
  @aws_access_key        = config['aws_access_key']
  @aws_secret_access_key = config['aws_secret_access_key']
  @private_key_file      = config['private_key_file']
  @cert_file             = config['cert_file']
  @bucket_name           = config['bucket_name']
  @bundle_file_prefix    = config['bundle_file_prefix'] + "-v#{@version::MAJOR}_#{@version::MINOR}_#{@version::TINY}-#{arch_config[:name]}"
end

desc "Use the Amazon AMI tools to create an AMI bundle"
task :bundle => [:load_config, :install_ami_tools] do |t|
  unless_completed(t) do
    # copy cert files into @fs_dir/tmp
    cp @private_key_file, "#{@fs_dir}/tmp"
    cp @cert_file,        "#{@fs_dir}/tmp"
    
    env = "RUBYLIB=/usr/lib/ruby/1.8:/usr/local/lib/1.8/i486-linux:/usr/lib/site_ruby"
    run_chroot "sh -c '#{env} ec2-bundle-vol -r #{arch_config[:name]} -e /tmp -d /tmp -k /tmp/#{File.basename(@private_key_file)} -c /tmp/#{File.basename(@cert_file)} -u #{@aws_account_id} -p #{@bundle_file_prefix}'"
  end
end

desc "Upload the AMI bundle to EC2"
task :upload_bundle => :bundle do |t|
  unless_completed(t) do
    env = "RUBYLIB=/usr/lib/ruby/1.8:/usr/local/lib/1.8/i486-linux:/usr/lib/site_ruby"
    run_chroot "sh -c '#{env} ec2-upload-bundle -b #{@bucket_name} -m /tmp/#{@bundle_file_prefix}.manifest.xml -a #{@aws_access_key} -s #{@aws_secret_access_key}'"
  end
end

desc "Register the EC2 image (requires Amazon EC2 API Java command-line tools to be installed with environment variables set)"
task :register_image => [:load_config, :upload_bundle] do |t|
  unless_completed(t) do
    run "ec2-register #{@bucket_name}/#{@bundle_file_prefix}.manifest.xml"
  end
end

desc "This task is for deploying the contents of /files to a running server image to test config file changes without rebuilding."
task :deploy_files do |t|
  # TODO allow user to specify key and hostname
  run "rsync -rlvzcC --rsh='ssh -l root -i #{ENV['key']}' files/ #{ENV['host']}:/"
end

desc  "This task creates a patch file containing all local modifications"
task :create_patch do |t|
  run "svn diff > patch.txt"
  puts "Created a patch file named 'patch.txt'"
end

task :check_if_root do |t|
  user = `whoami`.strip
  if user != 'root'
    raise "Sorry, this buildfile must be run as root (it appears to be running as #{user}. I don't like it either, help me fix this! (See comments in build file for more info.)"
  end
  # Some things that might help fix this problem:
  # fakeroot fakechroot chroot <command>
  # debootstrap --variant=fakechroot
  # mount also requires root 
end

##################

# Execute a given block and touch a stampfile. The block won't be run if the stampfile exists.
def unless_completed(task, &proc)
  stampfile = "#{@output_dir}/#{task.name}.completed"
  unless File.exists?(stampfile)
    yield  
    touch stampfile
  end
end

def run_chroot(command, ignore_error = false)
  run "chroot '#{@fs_dir}' #{command}"
end

def run(command, ignore_error = false)
  puts "*** #{command}" 
  result = system command
  raise("error: #{$?}") unless result || ignore_error
end

def mounted?(mount_point)
  mount_point_regex = mount_point.gsub(/\//, "\\/")
  `mount`.select {|line| line.match(/#{mount_point_regex}/) }.any?
end

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