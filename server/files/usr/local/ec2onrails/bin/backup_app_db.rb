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

require File.join(File.dirname(__FILE__), 's3_lib')


load_db_config
load_s3_config

cmd = "mysqldump --opt --skip-add-locks -u#{@user} "
cmd += " -p'#{@password}' " unless @password.nil?
cmd += " #{@database} | gzip > #{File.join(@archive_dir, @archive_filename)}"
result = system(cmd)
raise("mysqldump error: #{$?}") unless result

AWS::S3::Base.establish_connection!(:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_access_key, :use_ssl => true)

# include the hostname in the bucket name so test instances don't accidentally clobber real backups
bucket_name = "#{@bucket_base_name}_backup_#{hostname}"
create_bucket(bucket_name)
AWS::S3::S3Object.store(@archive_filename, open(File.join(@archive_dir, @archive_filename)), bucket_name)
