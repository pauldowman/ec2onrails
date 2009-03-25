begin
  require 'echoe'
rescue LoadError
  abort "You'll need to have `echoe' installed to use ec2onrails' Rakefile"
end

require "./echoe_config"

desc "Run all gem-related tasks"
task :ec2onrails_gem => [:manifest, :package, :update_github_gemspec]

desc "Update the GitHub gemspec file (/ec2onrails.gemspec)"
task :update_github_gemspec => [:manifest, :package] do
  root_dir = File.dirname __FILE__
  contents = File.open("#{root_dir}/pkg/ec2onrails-#{Ec2onrails::VERSION::STRING}/ec2onrails.gemspec", 'r').readlines
  File.open("#{root_dir}/ec2onrails.gemspec", 'w') do |f|
    f << "# This file is auto-generated, do not edit.\n"
    f << "# Edit echoe_config.rb and then run 'rake ec2onrails_gem'\n"
    f << "# \n"
    contents.each {|line| f << line}
  end
end  

