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


#TODO:
# if not in a role, we want to make sure that the service is stopped....
# it gets a little tricky with the web_proxy, which is not enabled if it is
# not already in a web role. Leave as is, as all it does is throw an error
# until GOD is in the picture, at which case it should be easy to enable
# and let it handle it instead of the init.d script....
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
  #we symlink the web_proxy we are using....
  start(:web, "web_proxy", 'nginx apache')
  # sleep(5)
  # run("/etc/init.d/web_proxy reload")
else
  #not started...
  stop(:web, "web_proxy", 'nginx apache')
end


# app role:
if in_role?(:app)
  start(:app, "mongrel", "mongrel_rails")
else
  stop(:app, "mongrel", "mongrel_rails")
end
