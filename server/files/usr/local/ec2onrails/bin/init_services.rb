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


# memcache role:
if in_role?(:memcache)
  # increase memory size, etc if no other roles exist?
  start(:memcache, "memcached")
else
  stop(:memcache, "memcached")
end

# db primary role:
if in_role?(:db_primary)
  # increase caches, etc if no other roles exist?
  start(:db_primary, "mysql", "mysqld")
else
  stop(:db_primary, "mysql", "mysqld")
end

# web role:
if in_role?(:web)
  #we symlink the web_proxy we are using....
  start(:web, "web_proxy")
  sleep(5)
  run("/etc/init.d/web_proxy reload")
else
  stop(:web, "web_proxy")
end


# app role:
if in_role?(:app)
  start(:app, "mongrel", "mongrel_rails")
else
  stop(:app, "mongrel", "mongrel_rails")
end
