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
    
    def self.load_config
      config = {}
      begin
        config = eval(File.read("/etc/ec2onrails/config.rb"))
      rescue Exception => e
        puts "ERROR:\n#{e.inspect}\n#{e.backtrace.join("\n")}"
      end
      return config
    end
  end
end
