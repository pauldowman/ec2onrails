module Ec2onrails
  module CapistranoUtils
    def run_local(command)
      result = system command
      raise("error: #{$?}") unless result
    end
    
    def run_init_script(script, arg)
      # since init scripts might have the execute bit unset by the set_roles script we need to check
      sudo "sh -c 'if [ -x /etc/init.d/#{script} ] ; then /etc/init.d/#{script} #{arg}; fi'"
    end
    
    # return hostnames for the role named role_sym that has the specified options
    def hostnames_for_role(role_sym, options = {})
      role = roles[role_sym]
      unless role
        return []
      end
      role.select{|s| s.options == options}.collect{|s| s.host}
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
