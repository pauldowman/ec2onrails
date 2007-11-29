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
require 'optiflag'

include FileUtils

module CommandLineArgs extend OptiFlagSet
  optional_flag "bucket"
  optional_flag "file"

  and_process!
end

@temp_dir = "/tmp/ec2onrails-backup-#{Time.new.to_i}"
@config_file = "/mnt/app/current/config/s3.yml"

def setup
  mkdir_p @temp_dir
  
  # include the hostname in the bucket name so test instances don't accidentally clobber real backups
  @bucket_name = ARGV.flags.bucket || "#{@bucket_base_name}_backup_#{hostname}"
  @archive_file = ARGV.flags.file || @default_archive_file
  
  AWS::S3::Base.establish_connection!(:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_access_key, :use_ssl => true)
end

def cleanup
  rm_rf @temp_dir
end

def create_bucket(name)
  begin
    AWS::S3::Bucket.find(name)  
  rescue AWS::S3::NoSuchBucket
    AWS::S3::Bucket.create(name)
  end
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

def store_file
  create_bucket(@bucket_name)
  AWS::S3::S3Object.store(File.basename(@archive_file), open(@archive_file), @bucket_name)
end

def retrieve_file(dir)
  open(@archive_file, 'w') do |file|
    AWS::S3::S3Object.stream(File.basename(@archive_file), @bucket_name) do |chunk|
      file.write chunk
    end
  end
end

# load an env value from the shared config file
def get_bash_config(name)
  `bash -c 'source /mnt/aws-config/config; echo $#{name}'`.strip
end

def hostname
  `hostname -s`.strip
end

