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
#    To customize the nginx config files, you can setup a template like:
#    /etc/ec2onrails/balancer_members.erb
#    /etc/ec2onrails/nginx_upstream_members.erb
#

require 'erb'
require "#{File.dirname(__FILE__)}/../lib/roles_helper"
include Ec2onrails::RolesHelper

puts "Roles: "
pp roles


# web role:
if in_role?(:web)
  puts "setting up reverse proxy for web role.  starting port: #{web_starting_port} up to #{web_starting_port + web_num_instances - 1}"
  
  ## lets update/modify web balancer file templates, if need be
  files_written = []
  Dir["/etc/ec2onrails/*.erb"].each do |filename|
    #what other variables would be helpful?
    @web_port_range = web_port_range
    @web_starting_port = web_starting_port
    @roles = roles
    file = ERB.new(IO.read(filename)).result(binding)
    file_name = filename.sub(/\.erb$/, '')
    files_written << file_name
    File.open(file_name, 'w'){|f| f << file}
  end
  
  nginx_config_file = "/etc/ec2onrails/nginx_upstream_members"
  unless files_written.index(nginx_config_file)
    File.open(nginx_config_file, "w") do |f|
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

if roles[:db_primary]
  db_primary_addr = roles[:db_primary][0]
  add_etc_hosts_entry('db_primary', db_primary_addr)
end


