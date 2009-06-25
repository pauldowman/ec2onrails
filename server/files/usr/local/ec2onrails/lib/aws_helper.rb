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
require 'yaml'
require 'erb'
require 'fileutils'
require "#{File.dirname(__FILE__)}/utils"

module Ec2onrails
  class AwsHelper

    DEFAULT_CONFIG_FILE = "/mnt/app/current/config/aws.yml"
    DEFAULT_CONFIG_FILE_OLD = "/mnt/app/current/config/s3.yml"

    # make attributes available for specs
    attr_accessor :config_file
    attr_accessor :rails_env
    attr_accessor :aws_access_key
    attr_accessor :aws_secret_access_key
    attr_accessor :bucket_base_name

    def initialize(config_file = AwsHelper.default_config_file, rails_env = Utils.rails_env)
      @rails_env = rails_env
      @config_file = config_file

      if File.exists?(@config_file)
        aws_config = YAML::load(ERB.new(File.read(@config_file)).result)

        # try to load the section for the current RAILS_ENV
        section = aws_config[@rails_env]
        if section.nil?
          # fall back to keys at the root of the tree
          section = aws_config
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

    # load an env value from the shared config file
    def get_bash_config(name)
      `bash -c 'source /mnt/aws-config/config; echo $#{name}'`.strip
    end   
    
    def self.default_config_file
      File.exists?(DEFAULT_CONFIG_FILE) ? DEFAULT_CONFIG_FILE : DEFAULT_CONFIG_FILE_OLD
    end
    
  end
end
