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

module Ec2onrails
  class S3Helper

    DEFAULT_CONFIG_FILE = "/mnt/app/current/config/s3.yml"
  
    # make attributes available for specs
    attr_accessor :bucket
    attr_accessor :dir
    attr_accessor :config_file
    attr_accessor :rails_env
    attr_accessor :aws_access_key
    attr_accessor :aws_secret_access_key
    attr_accessor :bucket

    def initialize(bucket, dir, config_file = DEFAULT_CONFIG_FILE, rails_env = Utils.rails_env)
      @dir = dir
      @config_file = config_file
      @rails_env = rails_env
      load_s3_config
      @bucket = bucket || "#{@bucket_base_name}-#{Ec2onrails::Utils.hostname}"
      AWS::S3::Base.establish_connection!(:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_access_key, :use_ssl => true)
    end

    def load_s3_config
      if File.exists?(@config_file)
        s3_config = YAML::load(ERB.new(File.read(@config_file)).result)
    
        # try to load the section for the current RAILS_ENV
        section = s3_config[@rails_env]
        if section.nil?
          # fall back to keys at the root of the tree
          section = s3_config
        end
    
        @aws_access_key        = section['aws_access_key']
        @aws_secret_access_key = section['aws_secret_access_key']
        @bucket_base_name      = section['bucket_base_name']
      else
        if !File.exists?('/mnt/aws-config/config')
          raise "Can't find either #{@config_file} or /mnt/aws-config/config"
        end
        @aws_access_key        = get_bash_config('AWS_ACCESS_KEY_ID')
        @aws_secret_access_key = get_bash_config('AWS_SECRET_ACCESS_KEY')
        @bucket_base_name      = get_bash_config('BUCKET_BASE_NAME')  
      end
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

    # load an env value from the shared config file
    def get_bash_config(name)
      `bash -c 'source /mnt/aws-config/config; echo $#{name}'`.strip
    end
  end
end
