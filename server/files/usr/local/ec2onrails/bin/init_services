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

require "#{File.dirname(__FILE__)}/../lib/roles_helper"
include Ec2onrails::RolesHelper


APP_ROOT = "/mnt/app/current"
RAILS_ENV = `/usr/local/ec2onrails/bin/rails_env`.strip

#reload configs to pick up any new changes
Dir.glob("/etc/god/*.god") + Dir.glob("/mnt/app/current/config/god/#{RAILS_ENV}/*.god").each do |f|
  sudo "god load '#{f}'"
end

# memcache role:
if in_role?(:memcache)
  # increase memory size, etc if no other roles exist?
  start(:memcache, "memcached")
else
  stop(:memcache, "memcached")
end

# db primary role:
if in_role?(:db_primary)
  start(:db, "mysql", "mysqld")
else
  stop(:db, "mysql", "mysqld")
end

# web role:
if in_role?(:web)
  start(:web, "nginx", "nginx")
else
  #not started...
  stop(:web, "nginx", "nginx")
end


# app role:
if in_role?(:app)
  start(:app, "mongrel", "mongrel_rails")
else
  stop(:app, "mongrel", "mongrel_rails")
end
