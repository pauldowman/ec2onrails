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
  class MysqlHelper

    DEFAULT_CONFIG_FILE = "/mnt/app/current/config/database.yml"

    attr_accessor :database
    attr_accessor :user
    attr_accessor :password

    def initialize(config_file = DEFAULT_CONFIG_FILE, rails_env = Utils.rails_env)
      @rails_env = rails_env
      load_db_config(config_file)
    end

    def load_db_config(config_file)
      db_config = YAML::load(ERB.new(File.read(config_file)).result)
      if db_config && db_config[@rails_env].nil?
        puts "the rails environment '#{@rails_env}' was not found in this db config file: #{config_file}"
      end
      db_config = db_config[@rails_env]
      @database = db_config['database']
      @user = db_config['username']
      @password = db_config['password']
    end

    def execute_sql(sql)
      raise "@user not set" unless @user
      raise "sql not given" unless sql
      cmd = %{mysql -u #{@user} -e "#{sql}"}
      cmd += " -p'#{@password}' " unless @password.nil?
      Utils.run cmd
    end
    
    def execute
      require "mysql"
      
      begin
        # connect to the MySQL server
        dbh = Mysql.real_connect("localhost", "#{@user}", "#{@password}", "#{@database}")
        yield dbh
      rescue Mysql::Error => e
        puts "Error code: #{e.errno}"
        puts "Error message: #{e.error}"
        puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
      ensure
        # disconnect from server
        dbh.close if dbh
      end
      
      
    end
    
    def dump(out_file, reset_logs)
      cmd = "mysqldump --quick --single-transaction --create-options -u#{@user} "
      if reset_logs
        cmd += " --flush-logs --master-data=2 --delete-master-logs "
      end
      cmd += " -p'#{@password}' " unless @password.nil?
      cmd += " #{@database} | gzip > #{out_file}"
      Utils.run cmd    
    end
    
    def load_from_dump(in_file)
      cmd = "gunzip -c #{in_file} | mysql -u#{@user} "
      cmd += " -p'#{@password}' " unless @password.nil?
      cmd += " #{@database}"
      Utils.run cmd
    end
    
    def execute_binary_log(log_file)
      cmd = "mysqlbinlog --database=#{@database} #{log_file} | mysql -u#{@user} "
      cmd += " -p'#{@password}' " unless @password.nil?
      Utils.run cmd
    end
  end
end