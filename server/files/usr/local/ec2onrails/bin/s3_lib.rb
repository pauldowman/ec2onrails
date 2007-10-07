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

require 'rubygems'
require 'aws/s3'
require 'yaml'
require 'erb'
require 'fileutils'

include FileUtils

@default_archive_filename = "app.sql.gz"
@temp_dir = "/tmp/ec2onrails-db-backup-#{Time.new.to_i}"
@config_file = "/mnt/app/current/config/s3.yml"


def setup
  mkdir_p @temp_dir
  
  @bucket_name = ARGV[0]
  if ! @bucket_name || @bucket_name.empty?
    # include the hostname in the bucket name so test instances don't accidentally clobber real backups
    @bucket_name = "#{@bucket_base_name}_backup_#{hostname}"
  end

  @archive_filename = ARGV[1]
  if ! @archive_filename || @archive_filename.empty?
    @archive_filename = @default_archive_filename
  end
end

def cleanup
  rm_rf @temp_dir
end

def create_bucket(name)
  bucket = AWS::S3::Bucket.find(name)  
rescue AWS::S3::NoSuchBucket
  AWS::S3::Bucket.create(name)
end

def load_db_config
  db_config = YAML::load(ERB.new(File.read("/mnt/app/current/config/database.yml")).result)
  @database = db_config['production']['database']
  @user = db_config['production']['username']
  @password = db_config['production']['password']
end

def load_s3_config
  if File.exists?(@config_file)
    s3_config = YAML::load(ERB.new(File.read("/mnt/app/current/config/s3.yml")).result)
    @aws_access_key        = s3_config['aws_access_key']
    @aws_secret_access_key = s3_config['aws_secret_access_key']
    @bucket_base_name      = s3_config['bucket_base_name']
  else
    if !File.exists?('/mnt/aws-config/config')
      raise "Can't find either #{@config_file} or /mnt/aws-config/config"
    end
    @aws_access_key        = get_bash_config('AWS_ACCESS_KEY_ID')
    @aws_secret_access_key = get_bash_config('AWS_SECRET_ACCESS_KEY')
    @bucket_base_name      = get_bash_config('BUCKET_BASE_NAME')  
  end
end

# load an env value from the shared config file
def get_bash_config(name)
  `bash -c 'source /mnt/aws-config/config; echo $#{name}'`.strip
end

def hostname
  `hostname -s`.strip
end

