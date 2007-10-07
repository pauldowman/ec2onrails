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
  end
end