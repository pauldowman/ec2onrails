require "./lib/ec2onrails/version"
 
begin
  require 'echoe'
rescue LoadError
  abort "You'll need to have `echoe' installed to use ec2onrails' Rakefile"
end
 
version = Ec2onrails::VERSION::STRING.dup
 
Echoe.new('ec2onrails', version) do |p|
  p.changelog        = "CHANGELOG"
 
  p.author           = ['Paul Dowman', 'Adam Greene']
  p.email            = "paul@pauldowman.com"
 
  p.summary = <<-DESC.strip.gsub(/\n\s+/, " ")
    Client-side libraries (Capistrano tasks) for managing and 
    deploying to EC2 on Rails servers.
  DESC
  
  #OTHER helpful options
  # p.install_message = "perhaps telling them where to find the example docs?"
  # p.rdoc_pattern
  p.url              = "http://ec2onrails.rubyforge.org"
  p.need_zip         = true
  p.rdoc_pattern     = /^(lib|README.textile|CHANGELOG)/
 
  p.dependencies     = [
                        'capistrano           >=2.4.3', 
                        'archive-tar-minitar  >=0.5.2', 
                        'optiflag             >=0.6.5']
                        
  p.development_dependencies = ['rake >=0.7.1']
  
  
end
