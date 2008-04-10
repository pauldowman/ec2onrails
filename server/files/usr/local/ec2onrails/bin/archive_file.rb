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

# This script archives a file to S3

require "rubygems"
require "optiflag"
require "#{File.dirname(__FILE__)}/../lib/s3_helper"
require "#{File.dirname(__FILE__)}/../lib/utils"

include FileUtils

module CommandLineArgs extend OptiFlagSet
  optional_flag "bucket"
  optional_flag "dir"
  optional_flag "file"
  and_process!
end

# include the hostname in the bucket name so test instances don't accidentally clobber real backups
bucket = ARGV.flags.bucket || Ec2onrails::Utils.hostname
dir = ARGV.flags.dir
@file = ARGV.flags.file
exit unless File.exists?(@file)

@s3 = Ec2onrails::S3Helper.new(@bucket, @dir)
@s3.store_file(@file)
