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
  
require "rubygems"
require "optiflag"
require "fileutils"
require 'EC2'
require "#{File.dirname(__FILE__)}/../lib/mysql_helper"
require "#{File.dirname(__FILE__)}/../lib/s3_helper"
require "#{File.dirname(__FILE__)}/../lib/aws_helper"
require "#{File.dirname(__FILE__)}/../lib/roles_helper"

require "#{File.dirname(__FILE__)}/../lib/utils"

# Only run if this instance is the db_pimrary
# The original code would run on any instance that had /etc/init.d/mysql
# Which was pretty much all instances no matter what role
include Ec2onrails::RolesHelper


module CommandLineArgs extend OptiFlagSet
  curr_env = Ec2onrails::Utils.rails_env
  default_bucket = "#{curr_env}_backup"

  flag "dir" do
    description "the directory that will be tarred and compressed and put on S3 with the name DIR_#{Ec2onrails::Utils.hostname}_TIMESTAMP.tgz"
  end
  
  optional_flag "role" do
    description "The role of this server, as defined by capistrano. ex. 'db', or 'app'  If not used, will be applied to all roles"
  end

  optional_flag "only_env" do
    description "Only apply the script if it is running within this environment"
  end
  
  optional_flag "bucket" do
    description "The s3 bucket you would like to save this backup to.  Will default to #{default_bucket}"
  end

  optional_switch_flag "v" do
    description "let you know if the script stopped because it was running in either a different role or environment than the one specified"
  end
  
  and_process!
end
curr_env = Ec2onrails::Utils.rails_env
default_bucket = "#{curr_env}_backup"

verbose = ARGV.flags.v
dir = ARGV.flags.dir
bucket = ARGV.flags.bucket || default_bucket
curr_env = Ec2onrails::Utils.rails_env
default_bucket = "#{curr_env}_backup"

if ARGV.flags.role && !in_role?(ARGV.flags.role.sub(/^:/, '').to_sym)
  puts "This script is not being run because the server is not running under the #{role} role" if verbose
  exit
end

if ARGV.flags.only_env && ARGV.flags.only_env.strip.downcase != curr_env.strip.downcase
  puts "This script is not being run because the server is not running under the #{curr_env} environment" if verbose
  exit
end

if !dir || File.exists?(dir)
  puts "The directory '#{dir}' does not exist.  Please enter a valid, full path to a directory you would like backed up" if verbose
end


@s3 = Ec2onrails::S3Helper.new(bucket, dir)
@s3.store_dir(dir, :compress => true)
