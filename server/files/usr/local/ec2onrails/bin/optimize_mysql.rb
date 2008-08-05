#!/usr/bin/ruby


## Notes about optimizations are inline below.
#  based upon recommendations listed here:
#  http://www.mysqlperformanceblog.com/2006/09/29/what-to-tune-in-mysql-server-after-installation/
#
#  For best effect, call this script after every other service has been started.
#

require 'fileutils'
require "/usr/local/ec2onrails/lib/roles_helper"
require "/usr/local/ec2onrails/lib/vendor/ini"
require "/usr/local/ec2onrails/lib/mysql_helper"
require "/usr/local/ec2onrails/lib/utils"

include Ec2onrails::RolesHelper

DEFAULT_CONFIG_LOC = "/etc/mysql/my.cnf"

exit unless in_role(:db_primary)

local_roles = roles.inject([]){|all_roles, role| all_roles << role.first if role.last.include?("127.0.0.1")}
only_db_role = local_roles.size < 2


#lets make a copy of the original...but do not overwrite if it already exists!
FileUtils.copy(DEFAULT_CONFIG_LOC, "#{DEFAULT_CONFIG_LOC}.pre_optimized") unless File.exists?("#{DEFAULT_CONFIG_LOC}.pre_optimized")


##### ************************** COMPUTE METRICS ************************** #####
#  define metrics used to modify my.cnf.  These metrics are used as guidelines
#  and are not meant to be exact measurements or limits.
#
#    * how much free memory is available?
#
#    * how many other roles is the db server taking on?  Based upon the type
#      and number of other roles, change the amout of memory we should dedicate
#      to the db.  This ratio is not the absolute ratio but is used as a guideline
# 
#    * how many cores does the slice have.  Then, based upon the Engineyard
#      recommendation that upto 4 mongrels generally take up one core, compute
#      the number of estimated available cores
#
#    * how many max connections are allowed, and how many database tables exist
##### ************************ END COMPUTE METRICS ************************ #####

#default is one core
num_cores = `cat /proc/cpuinfo`.find_all{|o| o =~ /^\s*processor\s+/}.size rescue 1
#if also running app, just search for ruby because that will 
#include mongrel but also daemons and other scripts
num_ruby_instances = local_roles.include?(:app) ? `ps ax | grep ruby | grep -v 'grep ruby'`.split("\n").size : 0
avail_cores = num_cores - num_ruby_instances/4
avail_cores = 0 if avail_cores.nil? || avail_cores < 0


mem_opt = nil
mem_opt ||= 0.15 if local_roles.include?(:app) && local_roles.include?(:web) && local_roles.include?(:memcached)
mem_opt ||= 0.25 if local_roles.include?(:app) && local_roles.include?(:memcached)
mem_opt ||= 0.35 if local_roles.include?(:app) || local_roles.include?(:memcached)
mem_opt ||= 0.50 if local_roles.include?(:web)
mem_opt ||= 0.70  #if only db, lets use a 70% ratio

orig_free_mem  = (`free -m` =~ /buffers\/cache:\s+\d+\s+(\d+)/; $1).to_i rescue 1024 

#TODO: take into account memcached settings if memcached is running on this server
ruby_mem_reserved = num_ruby_instances * 180
if orig_free_mem > 4098 && (orig_free_mem * mem_opt + ruby_mem_reserved) * 1.25 < orig_free_mem
  mem_opt *= 1.5
end
free_mem = (orig_free_mem * mem_opt).to_i

@mysql = Ec2onrails::MysqlHelper.new
         
result = run("/etc/init.d/mysql start")
  if result
    puts <<-MSG
****** WOOPS ******
mysql was not successfully started up.  
Not optimizing mysql config file
MSG
  exit 1
  end

num_connections = 100
mysql_cmd = %{mysql -u #{@mysql.user} -e "select @@max_connections;"}
mysql_cmd += " -p'#{@mysql.password}' " unless @mysql.password.nil?
if `#{mysql_cmd}` =~ /(\d+)/imx
  num_connections = $1.to_i
end

num_tables = 100
mysql_cmd = %{mysql -u #{@mysql.user} -e "SELECT count(*) TABLES from information_schema.tables where TABLE_SCHEMA = '#{@mysql.database}';"}
mysql_cmd += " -p'#{@mysql.password}' " unless @mysql.password.nil?
if `#{mysql_cmd}` =~ /(\d+)/imx
  num_tables = $1.to_i
end

# the default my.cnf is already different than the default example files... it has already
# been modified for ec2.  So lets use that one rather than starting from scratch again.
# default_mysql_config = if free_mem > 2048
#                          "my-huge.cnf" 
#                        elsif free_mem > 768
#                          "my-large.cnf"
#                        else
#                          "my-medium.cnf"
#                        end

puts <<-MSG

Optimizing mysql based off of these stats:
  * sharing server with these roles : #{local_roles.inspect}
  * num cores (est avail cores)     : #{num_cores} (#{avail_cores})
  * avail mem (mem for db)          : #{orig_free_mem} (#{free_mem})
  * num database tables             : #{num_tables}
  * max num conns                   : #{num_connections}
MSG


#lets figure out which default config file to start with:
# new_config = "/etc/mysql/#{default_mysql_config}"


##### ******************** Modifying MYSQL config file ******************** #####
configs = Ini.load(DEFAULT_CONFIG_LOC, :comment => '#')
configs['mysqld']['key_buffer_size'] ||= configs['mysqld']['key_buffer']

modifying_keys = %w(thread_concurency thread_cache_size query_cache_size table_cache 
                    key_buffer_size innodb_flush_log_at_trx_commit 
                    innodb_buffer_pool_size innodb_additional_mem_pool_size 
                    innodb_log_buffer_size innodb_log_file_size)

original_values = modifying_keys.inject([]){|all, key| all << [key, configs['mysqld'][key.to_s]]}


##### thread_concurency: only turn on thread concurrency if 
#     there are some spare 'cores' available
if avail_cores < 2
  configs['mysqld'].delete('thread_concurency')
elsif
  # Try number of CPU's*2 for thread_concurrency
  configs['mysqld']['thread_concurency'] = (avail_cores) * 2
end


#### thread_cache: we don't want threads being created on a regular basis, but 
#    if we don't have available cores it doesn't make much sense to cache
#    to many threads
configs['mysqld']['thread_cache_size'] = if avail_cores > 6
                                           24
                                         elsif avail_cores > 3
                                           16
                                         else
                                           8
                                         end


#### query_cache_size: Important for read-heavy db loads, but it gets expensive
#    to maintain if it gets too large.
configs['mysqld']['query_cache_size'] = if free_mem > 4096
                                          only_db_role ? 512 : 384
                                        elsif free_mem > 2048
                                          only_db_role ? 256 : 128
                                        elsif free_mem > 1024
                                          only_db_role ? 128 : 64
                                        else
                                          64
                                        end
configs['mysqld']['query_cache_size'] = "#{configs['mysqld']['query_cache_size']}M"


#### table_cache: Opening tables can be expensive, so this cache helps mitigate that.  
# Each connection needs its own entry in the table cache, but this is less important for innodb 
# heavy database (which most rails apps are).
# based upont he observation that a cache size of 1024 is a good size for a db with a few hundred tables
configs['mysqld']['table_cache'] = (num_connections * num_tables)/10


#### key_buffer_size: Does not need to be very large because most rails 
#    applications do not use MyISAM, or use if very little (usually to store
#    db-based sessions).  Keep space available for temp tables and other
#    little mysql needs
configs['mysqld']['key_buffer_size'] = if free_mem > 4096
                                    only_db_role ? 256 : 128
                                  elsif free_mem > 2048
                                    only_db_role ? 128 : 64
                                  elsif free_mem > 1024
                                    only_db_role ? 64 : 32
                                  else
                                    16
                                  end
configs['mysqld']['key_buffer_size'] = "#{configs['mysqld']['key_buffer_size']}M"
#can use either key_buffer or key_buffer_size.  
#Since we are using key_buffer_size, lets remove the other one
configs['mysqld'].delete('key_buffer') 


#### innodb_flush_log_at_trx_commit: this makes INNODB *much* faster, but
#    it is not 100% ACID compliant.  Instead of flushing to disk for every
#    commit, this flushes to the OS file cache.  That means that if MySQL
#    crashes, the data will be written, but if the OS crashes, 1-2
#    seconds of information could be lost
configs['mysqld']['innodb_flush_log_at_trx_commit'] = 2


# * innodb_buffer_pool_size upto 70% of memory..but if sharing and small data sizes, use less (50%?)

#### innodb_buffer_pool_size: this is where we should put most of our free memory, since
#    rails apps are heavy users of innodb.  Need to be careful NOT to specify TOO much memory
configs['mysqld']['innodb_buffer_pool_size'] = if free_mem > 4096
                                                 free_mem - 512
                                               elsif free_mem > 2048
                                                 free_mem - 384
                                               elsif free_mem > 1024
                                                 free_mem - 256
                                               elsif free_mem > 512
                                                 free_mem - 128
                                               elsif free_mem > 256
                                                 free_mem  - 64
                                               else
                                                 free_mem
                                               end
configs['mysqld']['innodb_buffer_pool_size'] = "#{configs['mysqld']['innodb_buffer_pool_size']}M"


#### innodb_additional_mem_pool_size: This is not really needed as most OS's do a good job
#    of allocating memory.
configs['mysqld']['innodb_additional_mem_pool_size'] ||= '16M'


#### innodb_log_buffer_size: This is flushed every second anyway, so 8-16M is generally ok
configs['mysqld']['innodb_log_buffer_size'] ||= '12M'


#### innodb_log_file_size: Help with heavy writes, 
#    BUT if it is too large recovery times can be a lot longer
configs['mysqld']['innodb_log_file_size'] = if free_mem > 4096
                                              512
                                            elsif free_mem > 2048
                                              256
                                            elsif free_mem > 1024
                                              128
                                            else
                                              64
                                            end
configs['mysqld']['innodb_log_file_size'] = "#{configs['mysqld']['innodb_log_file_size']}M"
##### ****************** END Modifying MYSQL config file ****************** #####



new_values = modifying_keys.inject([]){|all, key| all << [key, configs['mysqld'][key.to_s]]}
msg = "\nModified these mysqld parameters:\n"
msg += <<-MSG
  mysqld key: new value (original value)   
-----------------------------------------------  
MSG
new_values.each_with_index do |v, i|
  orig_value = original_values[i].last.nil? ? 'not set' : original_values[i].last
  msg += <<-MSG
  * #{v.first}: #{v.last} (#{orig_value})
  MSG
end
puts msg

config_file_loc = DEFAULT_CONFIG_LOC
#We need to shut down mysql BEFORE we move the new configs over...
puts "\nCleanly stopping mysql to replace its config file."

#make sure the mysql has time to startup before we shut it down again
#TODO: can we improve this?
sleep(5) 

result = run("/etc/init.d/mysql stop")
clean_stop = true
if result
  config_file_loc += ".optimized"
  clean_stop = false
  puts <<-MSG
****** WOOPS ******
mysql was not successfully shut down, so we dare not
update the config file (it can cause problems with the 
ib_logfile cache).  We have saved the new config file at
   #{config_file_loc}
in case you still want to use it in place of
   #{DEFAULT_CONFIG_LOC}
MSG
else
puts <<-MSG
cleanly shutdown mysql.  Replacing config file:
   #{config_file_loc}
The original config file can be found here:
   #{DEFAULT_CONFIG_LOC}.pre_optimized

Starting mysql...
MSG
end

configs.save(config_file_loc)

config_file = File.read(DEFAULT_CONFIG_LOC)
File.open(DEFAULT_CONFIG_LOC, 'w') do |file|
  file << <<-MSG
# This file is generated by '#{__FILE__}'
# Based upon the default '#{DEFAULT_CONFIG_LOC}'
# which is now saved at '#{DEFAULT_CONFIG_LOC}.pre_optimized'
    
# See file for comments:
# #{__FILE__}
#
#

MSG
  file << config_file
end

if clean_stop  
  #before we can start, we need to move the old cache files...
  old_logs = []
  Dir.glob("/mnt/mysql_data/ib_logfile*").each do |f|
    FileUtils.mv(f, f + "_old")
    old_logs << "#{f}_old"
  end
  puts <<-MSG
Moving the old mysql ib logfiles because we might have changed the
default logfile cache size.  If mysql startups up successfully,
these files can be removed:
  #{old_logs.join("\n  ")}
MSG


  result = run("/etc/init.d/mysql start")
  if result
    puts <<-MSG
****** WOOPS ******
mysql was not successfully started up.  
Check syslog, as the culprit will be logged there.
MSG
  end
end
