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
#
#
#    This file helps in setting up and retrieving ec2 meta-data
#    If a key is passed in, it will only retrieve that key
#    if not, then it will return all of the meta-data formatted in yaml
#

require "rubygems"
require "optiflag"
require 'yaml'
require "#{File.dirname(__FILE__)}/../lib/roles_helper"
include Ec2onrails::RolesHelper

CURL_OPTS  = "-s -S -f -L --retry 7"
META_URL   = "http://169.254.169.254/latest/meta-data"


module CommandLineArgs extend OptiFlagSet
  optional_flag "key" do
    description "The ec2 meta-data value you would like to look up"
  end
  and_process!
end


def process_files(files, root_url="")
  output = {}
  files.split.each do |file|
    if file =~ /\/$/
      output.merge! process_files(`curl #{CURL_OPTS} #{META_URL}/#{file}`, "#{file}") 
    else      
      if file =~ /=/
        key, data = file.split('=')        
      else
        url = "#{META_URL}/#{root_url}/#{file}"
        data = `curl #{CURL_OPTS} #{url}`
        raise "Failed to fetch entry #{file}: code #{$?.exitstatus} -- #{data}" unless $?.success?
      end
      if root_url.nil? || root_url.strip.length == 0
        output[file] = data
      else
        output[root_url] ||= {}
        output[root_url][file] = data
      end
    end
  end  
  output
end



if ARGV.flags.key
  puts get_metadata(ARGV.flags.key) 
else

  files = `curl #{CURL_OPTS} #{META_URL}/`
  raise "Failed to fetch directory: code #{$?.exitstatus} -- #{files}" unless $?.success?
  val = process_files(files)
  puts val.to_yaml
end

