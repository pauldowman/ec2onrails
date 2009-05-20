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
require "#{File.dirname(__FILE__)}/utils"
require "#{File.dirname(__FILE__)}/aws_helper"

module Ec2onrails
  class S3Helper
    SCRATCH_SPACE = '/mnt/tmp'

    # make attributes available for specs
    attr_accessor :bucket
    attr_accessor :dir
    attr_accessor :config_file
    attr_accessor :rails_env
    attr_accessor :aws_access_key
    attr_accessor :aws_secret_access_key
    attr_accessor :bucket

    def initialize(bucket, dir, config_file = Ec2onrails::AwsHelper.default_config_file, rails_env = Utils.rails_env)
      @dir = dir
      @config_file = config_file
      @rails_env = rails_env
      @awsHelper = Ec2onrails::AwsHelper.new(config_file, rails_env)
      @aws_access_key        = @awsHelper.aws_access_key
      @aws_secret_access_key = @awsHelper.aws_secret_access_key
      @bucket_base_name      = @awsHelper.bucket_base_name
      @bucket = bucket || "#{@bucket_base_name}-#{Ec2onrails::Utils.hostname}"
      AWS::S3::Base.establish_connection!(:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_access_key, :use_ssl => true)
    end

    def create_bucket
      retries = 0
      begin
        AWS::S3::Bucket.find(@bucket)
      rescue AWS::S3::NoSuchBucket
        AWS::S3::Bucket.create(@bucket)
        sleep 1 # If we try to use the bucket too quickly sometimes it's not found
        retry if (retries += 1) < 15
      end
    end

    def store_file(file)
      create_bucket
      AWS::S3::S3Object.store(s3_key(file), open(file), @bucket)
    end
    
    def store_dir(dir, options={})
      FileUtils.mkdir_p SCRATCH_SPACE
      create_bucket
      compress = options[:compress]
      exclude  = options[:exclude]
      
      #should be of the format:
      # mnt-app-shared_ec2-75-101-250-19__20090217-183411.tgz
      archive_nm = "#{Ec2onrails::Utils.hostname}__#{Time.new.strftime('%Y%m%d-%H%M%S')}"
      archive_nm += compress ? ".tgz" : 'tar'  
      cmd = "cd #{SCRATCH_SPACE} && tar -cph"
      cmd += 'z' if compress
      cmd += "f #{archive_nm} -C / #{dir[1..-1]} "
      cmd += " --exclude=#{exclude} "
      system(cmd)
      file = "#{SCRATCH_SPACE}/#{archive_nm}"
      AWS::S3::S3Object.store(s3_key(archive_nm), open(file), @bucket)
    ensure
      system "nice -n 15 rm -f #{file}" 
    end      

    def retrieve_file(file)
      key = s3_key(file)
      AWS::S3::S3Object.find(key, @bucket)
      open(file, 'w') do |f|
        AWS::S3::S3Object.stream(key, @bucket) do |chunk|
          f.write chunk
        end
      end
    end
    
    def list_keys(filename_prefix)
      prefix = @dir ? "#{@dir}/#{filename_prefix}" : filename_prefix
      AWS::S3::Bucket.objects(@bucket, :prefix => prefix).collect{|obj| obj.key}
    end
    
    def retrieve_files(filename_prefix, local_dir)
      list_keys(filename_prefix).each do |k|
        file = "#{local_dir}/#{File.basename(k)}"
        retrieve_file(file)
      end      
    end

    def delete_files(filename_prefix)
      list_keys(filename_prefix).each do |k|
        AWS::S3::S3Object.delete(k, @bucket)
      end
    end
  
    def s3_key(file)
      @dir ? "#{@dir}/#{File.basename(file)}" : File.basename(file)
    end
  end
end
