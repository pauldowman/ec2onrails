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

require 'erb'
require "#{File.dirname(__FILE__)}/../lib/roles_helper"
include Ec2onrails::RolesHelper

puts "Roles: "
pp roles


# web role:
if in_role?(:web)
  puts "setting up reverse proxy for web role.  starting port: #{web_starting_port} up to #{web_starting_port + web_num_instances - 1}"

  if system("which apache")
    File.open("/etc/ec2onrails/balancer_members", "w") do |f|
      roles[:app].each do |address|
        web_port_range.each do |port|
          f << "BalancerMember http://#{address}:#{port}\n"
        end
        f << "\n"
      end
    end
  end

  if system("which nginx")
    File.open("/etc/ec2onrails/nginx_upstream_members", "w") do |f|
      f << "upstream mongrel{\n"
      roles[:app].each do |address|
        web_port_range.each do |port|
          f << "\tserver #{address}:#{port};\n"
        end
      end
      f << "fair;\n}\n"
    end
  end
end

if in_role?(:db_primary) || in_role?(:app)
  db_primary_addr = roles[:db_primary][0]
  add_etc_hosts_entry('db_primary', db_primary_addr)
end


## lets update/modify monit files, if need be
ROOT_MONIT_CONFIGS = "/etc/monit"
Dir["/etc/monit/*.monitrc.erb"].each do |filename|
  #what other variables would be helpful?
  @web_port_range = web_port_range
  @web_starting_port = web_starting_port
  @roles = roles
  file = ERB.new(IO.read(filename)).result(binding)
  File.open(filename.sub(/\.erb$/, ''), 'w'){|f| f << file}
end

#time to reload any changes made
sudo "monit reload"

