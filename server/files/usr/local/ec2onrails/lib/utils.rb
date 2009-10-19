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
    
    def self.load_ec2onrails_config
      config_file = "/mnt/app/current/config/ec2onrails/config.rb"
      if File.exists?(config_file)
        config = eval(File.read(config_file))
      else
        puts "#{config_file} doesn't exist"
        config = {}
      end
      return config
    end
  end
end
