#!/usr/bin/ruby

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
#
#    enable either apache or nginx as the proxy server.  
#
#    to do this, we symlink a few folders to use a common name web_proxy,
#    which makes the handling of log files and what not easier to keep 
#    track of

require "rubygems"
require "optiflag"
require "#{File.dirname(__FILE__)}/../lib/roles_helper"
include Ec2onrails::RolesHelper

PROXY_CHOICES = ["apache","nginx"]
module CommandLineArgs extend OptiFlagSet
  flag "mode" do
    # this is our second new clause-level modifier
    value_in_set PROXY_CHOICES
    description "The web proxy server that will be installed and used."
  end
  and_process!
end

# make the log directories even if they won't be used...
# keeps logrotate configs easy
sudo "mkdir -p -m 755 /mnt/log/apache2"
sudo "mkdir -p -m 755 /mnt/log/nginx"

case ARGV.flags.mode
when 'apache'
  # it is a *LOT* easier to have apache2 pre-installed on the image 
  # (and have the default server configs placed after apache2 is installed)
  # 
  # so assume it is installed by this time
  # sudo "sh -c 'export DEBIAN_FRONTEND=noninteractive; aptitude -q -y install apache2'"
  
  sudo "a2enmod deflate"
  sudo "a2enmod proxy_balancer"
  sudo "a2enmod proxy_http"
  sudo "a2enmod rewrite"
  
  
  sudo "rm -rf /var/log/apache2"
  sudo "ln -sf /mnt/log/apache2 /var/log/apache2"
  sudo "ln -sf /etc/init.d/apache2 /etc/init.d/web_proxy"
  sudo "ln -sf /mnt/log/apache2 /mnt/log/web_proxy"
  
when 'nginx'
  #nginx does not have a precompiled package, so....
  
  src_dir = "#{Dir.pwd}/src"

  nginx_img = "http://sysoev.ru/nginx/nginx-0.6.34.tar.gz"
  fair_bal_img = "http://github.com/gnosek/nginx-upstream-fair/tarball/master"
  nginx_dir = "#{src_dir}/nginx"
  puts "installing nginx 6.32 (src dir: #{nginx_dir})"
  run "mkdir -p -m 755 #{nginx_dir} &&  rm -rf #{nginx_dir}/*"
  run "mkdir -p -m 755 #{nginx_dir}/modules/nginx-upstream-fair"
  run "cd #{nginx_dir} && wget -q #{nginx_img} && tar -xzf nginx-0.6.32.tar.gz"
  
  run "cd #{nginx_dir}/modules && \
       wget -q #{fair_bal_img} && \
       tar -xzf *nginx-upstream-fair*.tar.gz -o -C ./nginx-upstream-fair && \
       mv nginx-upstream-fair/*/* nginx-upstream-fair/."
       
  sudo "sh -c 'export DEBIAN_FRONTEND=noninteractive; aptitude -q -y install libpcre3-dev'"
    
  run "cd #{nginx_dir}/nginx-0.6.32 && \
       ./configure \
         --sbin-path=/usr/sbin \
         --conf-path=/etc/nginx/nginx.conf \
         --pid-path=/var/run/nginx.pid \
         --with-http_ssl_module \
         --with-http_stub_status_module \
         --add-module=#{nginx_dir}/modules/nginx-upstream-fair && \
       make && \
       sudo make install"

  run "sudo rm -rf /usr/local/nginx/logs; sudo ln -sf /mnt/log/nginx /usr/local/nginx/logs"
  #an init.d script is in the default server config... lets link it up
  sudo "ln -sf /etc/init.d/nginx /etc/init.d/web_proxy"
  sudo "ln -sf /mnt/log/nginx /mnt/log/web_proxy"
  # sudo "ln -sf /usr/local/nginx/sbin/nginx /usr/sbin/nginx"  
  # sudo "ln -sf /usr/local/nginx/conf /etc/nginx"
else
  puts "The mode: #{ARGV.flags.mode} was not recognized.  Must be one of these #{["apache","nginx"].join(', ')}"
  exit 1
end

#restart god... the config file will automatically pick up the changes but we need to restart god
sudo("/etc/init.d/god restart")
