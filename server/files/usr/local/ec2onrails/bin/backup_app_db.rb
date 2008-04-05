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

exit unless File.stat("/etc/init.d/mysql").executable?
exit unless File.exists?("/mnt/app/current")

require File.join("#{File.dirname(__FILE__)}/../s3_lib")

load_db_config
load_s3_config

@default_archive_file = "mysqldump.sql.gz"

module CommandLineArgs extend OptiFlagSet
  optional_switch_flag "full_backup"
  and_process!
end

begin
  setup
  if ARGV.flags.full_backup
    # Full backup, purge binary logs and do a mysqldump
    @archive_file = File.join(@temp_dir, @archive_file)
  
    run %{mysql -u root -e "reset master"}
  
    cmd = "mysqldump --flush-logs --single-transaction --skip-lock-tables --opt -u#{@user} "
    cmd += " -p'#{@password}' " unless @password.nil?
    cmd += " #{@database} | gzip > #{@archive_file}"
    run cmd

    run %{mysql -u root -e "purge master logs to 'mysql-bin.000002'"}
  
    store_file
  
    delete_files(@dir ? "#{@dir}/mysql-bin" : "mysql-bin")
  else
    # Incremental backup
    
    run %{mysql -u root -e "flush logs"}
    # TODO copy logs up to n-1 to s3
    run %{mysql -u root -e "purge master logs to 'mysql-bin.#{n}'"}
  end
ensure
  cleanup
end
