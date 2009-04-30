module Ec2onrails
  module Utils
    def self.run(command)
      result = system command
      raise("error, process exited with status #{$?.exitstatus}") unless result
    end
  
    def self.rails_env
      File.read("/etc/ec2onrails/rails_env").strip
    end
    
    def self.hostname
      `hostname -s`.strip
    end
  end
end