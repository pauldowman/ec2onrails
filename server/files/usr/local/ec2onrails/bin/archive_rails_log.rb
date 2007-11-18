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

exit unless File.exists?("/mnt/app/current/log")

require File.join(File.dirname(__FILE__), 's3_lib')

load_s3_config

begin
  setup
  
  @archive_filename = "production.log-#{Time.new.strftime('%Y%m%d')}.gz"
  
  AWS::S3::Base.establish_connection!(:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_access_key, :use_ssl => true)
  
  create_bucket(@bucket_name)
  AWS::S3::S3Object.store(@archive_filename, open(File.join("/mnt/app/current/log", @archive_filename)), @bucket_name)
ensure
  cleanup
end
