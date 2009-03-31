module Ec2onrails
  module CapistranoUtils
    def run_local(command)
      result = system command
      raise("error: #{$?}") unless result
    end
    
    def run_init_script(script, arg)
      # TODO only restart a service if it's already started. 
      # Aside from being smarter and more efficient, This will make sure we 
      # aren't starting a service that shouldn't be started for the current
      # roles (e.g. don't start nginx when we're not in the web role)
      # How? Maybe need another param with the process name?
      sudo "/etc/init.d/#{script} #{arg}"
    end
    
    # return hostnames for the role named role_sym that has the specified options
    def hostnames_for_role(role_sym, options = {})
      role = roles[role_sym]
      unless role
        return []
      end
      # make sure we match the server with all the passed in options, BUT the server can
      # have additional options defined.  e.g.: :primary => true and :ebs_vol_id => 'vol-1234abcd'
      # but we want to select the server where :primary => true
      role.select{|s| 
        match = true
        options.each_pair{|k,v| match = false if s.options[k] != v}
      }.collect{|s| s.host}
    end
    
    # Like the capture method, but does not print out error stream and swallows 
    # an exception if the process's exit code != 0
    def quiet_capture(command, options={})
      output = ""
      invoke_command(command, options.merge(:once => true)) do |ch, stream, data|
        case stream
        when :out then output << data
        # when :err then warn "[err :: #{ch[:server]}] #{data}"
        end
      end
    ensure
      return (output || '').strip
    end
    
  end
end
