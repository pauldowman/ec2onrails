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


require 'net/http'
require 'pp'
require 'socket'
require 'yaml'

def start(role, service, prog_name = service)
  # ensure script is executable
  run "chmod a+x /etc/init.d/#{service}"
  # start service if not running:
  unless (system("pidof -x #{prog_name}"))
    run "sh /etc/init.d/#{service} start && sleep 30" # give the service 30 seconds to start before attempting to monitor it
  end
  run "monit -g #{role} monitor all"
end

def stop(role, service, prog_name = service)
  run "monit -g #{role} unmonitor all"
  if (system("pidof -x #{prog_name}"))
    result = run("sh /etc/init.d/#{service} stop")
  end  
  # make start script non-executable in case of reboot
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
  if address == @local_address || address == @public_address
    "127.0.0.1"
  else
    address
  end
  rescue Exception => e
    puts "couldn't resolve hostname '#{hostname}'"
    raise e
end

def resolve_all_addresses(original)
  resolved = {}
  original.each do |rolename, hostnames|
    resolved[rolename] = hostnames.map{|hostname| resolve(hostname)} if hostnames
  end
  resolved
end

def in_role(role)
  return false unless @roles[role]
  return @roles[role].include?("127.0.0.1") 
end

ROLES_FILE = "/etc/ec2onrails/roles.yml"

@local_address  = get_address_metadata "local-ipv4"
@public_address = get_address_metadata "public-ipv4"

@roles = resolve_all_addresses(YAML::load_file(ROLES_FILE))
puts "Roles: "
pp @roles


puts "Adding db_primary to /etc/hosts..."
if @roles[:db_primary]
  db_primary_addr = @roles[:db_primary][0]
  puts "db_primary has ip address: #{db_primary_addr}"
  
  # TODO just use ruby here...
  run("cp /etc/hosts.original /etc/hosts")
  run("echo '\n#{db_primary_addr}\tdb_primary\n' >> /etc/hosts")
end
# TODO also add hostname for each memcache server


#######################################
# TODO move these role definitions each into it's own file so adding a new 
#      role is just dropping a ruby file into a directory

# memcache role:
if in_role(:memcache)
  puts "Starting memcache role..."
  # increase memory size, etc if no other roles exist?
  start(:memcache, "memcached")
else
  puts "Stopping memcache role..."
  stop(:memcache, "memcached")
end

# db primary role:
if in_role(:db_primary)
  puts "Starting db_primary role..."
  # increase caches, etc if no other roles exist?
  start(:db_primary, "mysql", "mysqld")
else
  puts "Stopping db_primary role..."
  stop(:db_primary, "mysql", "mysqld")
end

# web role:
if in_role(:web)
  puts "Starting web role..."
  balancer_members = File.open("/etc/ec2onrails/balancer_members", "w") do |f|
    @roles[:app].each do |address|
      (8000..8005).each do |port|
        f << "BalancerMember http://#{address}:#{port}\n"
      end
      f << "\n"
    end
  end
  start(:web, "apache2")
  # Force apache to reload config files in case it was already running and app hosts changed.
  run "/etc/init.d/apache2 reload"
else
  puts "Stopping web role..."
  stop(:web, "apache2")
end

# app role:
if in_role(:app)
  puts "Starting app role..."
  start(:app, "mongrel", "mongrel_rails")
else
  puts "Stopping app role..."
  stop(:app, "mongrel", "mongrel_rails")
end

#######################################
