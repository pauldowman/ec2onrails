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


require 'socket'
require 'net/http'
require 'pp'

def start(service, prog_name = service)
  # enable service if disabled:
  run("chmod a+x /etc/init.d/#{service}")
  
  # start service if not running:
  unless (system("pidof -x #{prog_name}"))
    result = run("sh /etc/init.d/#{service} start")
  end
end

def stop(service, prog_name = service)
  if (system("pidof -x #{prog_name}"))
    result = run("sh /etc/init.d/#{service} stop")
  end
  
  # disable service in case of reboot
  run("chmod a-x /etc/init.d/#{service}")
end

def run(cmd)
  result = system(cmd)
  puts("*****ERROR: #{cmd} returned #{$?}") unless result
end

def get_address_metadata(type)
  address  = Net::HTTP.get('169.254.169.254', "/2007-08-29/meta-data/#{type}").strip
  raise "couldn't get instance data: #{type}" unless address =~ /\A\d+\.\d+\.\d+\.\d+\Z/
  puts "#{type}: #{address}"
  return address
end

def resolve(hostname)
  address = IPSocket.getaddress(hostname).strip
  puts address
  if address == @local_address || address == @public_address
    "127.0.0.1"
  else
    address
  end
  rescue Exception => e
    puts "couldn't resolve hostname '#{hostname}'"
    raise e
end

def in_role(role)
  return false unless @roles[role]
  return @roles[role].include?("127.0.0.1") 
end

@local_address  = get_address_metadata "local-ipv4"
@public_address  = get_address_metadata "public-ipv4"

@roles = {}
$*.each do |arg|
  arg.match(/(.*)=(.*)/)
  role = $1
  hostnames = $2
  hostnames.split(',').each do |hostname|
    @roles[role] ||= []
    @roles[role] << resolve(hostname)
  end
end

pp @roles


#######################################
# TODO move these role definitions each into it's own file so adding a new 
#      role is just dropping a ruby file into a directory
#
# TODO add db_slave role, memcache role

# web role:
if in_role("web")
  puts "Starting web role..."
  balancer_members = File.open("/etc/ec2onrails/balancer_members", "w") do |f|
    @roles["app"].each do |address|
      (8000..8005).each do |port|
        f << "BalancerMember http://#{address}:#{port}\n"
      end
      f << "\n"
    end
  end
  start("apache2")
else
  puts "Stopping web role..."
  stop("apache2")
end

# app role:
if in_role("app")
  puts "Starting app role..."
  # edit /etc/hosts, need db_primary address & db_slave address
  db_primary_addr = @roles["db_primary"][0]
  puts "db_primary has ip address: #{db_primary_addr}"
  
  run("cp /etc/hosts.original /etc/hosts")
  run("echo '\n#{db_primary_addr}\tdb_primary\n' >> /etc/hosts")
  start("mongrel", "mongrel_rails")
else
  puts "Stopping app role..."
  stop("mongrel", "mongrel_rails")
end

# db primary role:
if in_role("db_primary")
  puts "Starting db_primary role..."
  # increase caches, etc if no other roles exist?
  start("mysql")
else
  puts "Stopping db_primary role..."
  stop("mysql")
end

# memcache role:
if in_role("memcache")
  puts "Starting memcache role..."
  # increase memory size, etc if no other roles exist?
  start("memcached")
else
  puts "Stopping memcache role..."
  stop("memcached")
end

#######################################
