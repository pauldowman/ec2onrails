module Ec2onrails
  module CapistranoUtils
    def run_local(command)
      result = system command
      raise("error: #{$?}") unless result
    end
    
    def make_admin_role_for(role, newrole_sym)
      roles[role].each do |srv_def|
        options = srv_def.options.dup
        options[:user] = "admin"
        options[:port] = srv_def.port
        options[:no_release] = true
        role newrole_sym, srv_def.host, options
      end
    end
    
    # return hostnames for the role named role_sym. It must have the options given or no hostnames will be returned
    def hostnames_for_role(role_sym, options = {})
      role = roles[role_sym]
      unless role
        return []
      end
      role.reject{|s| s.options != options}.collect{|s| s.host}.join(',')
    end
  end
end