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
require 'right_aws'
require 'yaml'
require 'erb'
require 'fileutils'
require "#{File.dirname(__FILE__)}/utils"
require "#{File.dirname(__FILE__)}/aws_helper"


# Hack to get rid of the "warning: peer certificate won't be verified in this SSL session" message
# See http://www.5dollarwhitebox.org/drupal/node/64
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end


module Ec2onrails
  class S3Helper
    SCRATCH_SPACE = '/mnt/tmp'

    # make attributes available for specs
    attr_accessor :dir
    attr_accessor :config_file
    attr_accessor :rails_env
    attr_accessor :aws_access_key
    attr_accessor :aws_secret_access_key
    attr_accessor :bucket_name

    def initialize(bucket_name, dir, config_file = Ec2onrails::AwsHelper.default_config_file, rails_env = Utils.rails_env)
      @dir = dir
      @config_file = config_file
      @rails_env = rails_env
      @awsHelper = Ec2onrails::AwsHelper.new(config_file, rails_env)
      @aws_access_key        = @awsHelper.aws_access_key
      @aws_secret_access_key = @awsHelper.aws_secret_access_key
      @bucket_base_name      = @awsHelper.bucket_base_name
      @bucket_name = bucket_name || "#{@bucket_base_name}-#{Ec2onrails::Utils.hostname}"
      logger = Logger.new(STDOUT)
      logger.level = Logger::ERROR
      s3 = RightAws::S3.new(@aws_access_key, @aws_secret_access_key, :logger => logger)
      @bucket = s3.bucket(@bucket_name, true)
    end

    def store_file(filename)
      @bucket.put(s3_key(filename), File.read(filename))
    end
    
    def store_dir(dir, options={})
      FileUtils.mkdir_p SCRATCH_SPACE
      compress = options[:compress]
      exclude  = options[:exclude]
      
      #should be of the format:
      # mnt-app-shared_ec2-75-101-250-19__20090217-183411.tgz
      archive_nm = "#{Ec2onrails::Utils.hostname}__#{Time.new.strftime('%Y%m%d-%H%M%S')}"
      archive_nm += compress ? ".tgz" : '.tar'  
      cmd = "cd #{SCRATCH_SPACE} && tar -cph"
      cmd += 'z' if compress
      cmd += "f #{archive_nm} -C / #{dir[1..-1]} "
      cmd += " --exclude=#{exclude} " if exclude
      system(cmd)
      file = "#{SCRATCH_SPACE}/#{archive_nm}"
      @bucket.put(s3_key(archive_nm), File.read(file))
    ensure
      system "nice -n 15 rm -f #{file}" 
    end      

    def retrieve_file(file)
      key = s3_key(file)
      open(file, 'w') { |f| f.write @bucket.get(key) }
    end
    
    def keys(filename_prefix)
      prefix = @dir ? "#{@dir}/#{filename_prefix}" : filename_prefix
      @bucket.keys('prefix' => prefix).collect{|key| key}
    end
    
    def retrieve_files(filename_prefix, local_dir)
      keys(filename_prefix).each do |k|
        file = "#{local_dir}/#{File.basename(k.to_s)}"
        retrieve_file(file)
      end      
    end

    def delete_files(filename_prefix)
      keys(filename_prefix).each { |k| k.delete }
    end
  
    def s3_key(file)
      @dir ? "#{@dir}/#{File.basename(file)}" : File.basename(file)
    end
  end
end
