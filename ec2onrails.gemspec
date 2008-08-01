Gem::Specification.new do |s|
  s.name = %q{ec2onrails}
  s.version = "0.9.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Dowman", "Adam Greene"]
  s.date = %q{2008-08-01}
  s.description = %q{Client-side libraries (Capistrano tasks) for managing and deploying to EC2 on Rails servers.}
  s.email = %q{paul@pauldowman.com}
  s.extra_rdoc_files = ["History.txt", 
                        "Manifest.txt", 
                        "website/index.txt"]
  s.files = ["History.txt", 
             "COPYING", 
             "Manifest.txt", 
             "README.rdoc", 
             "Rakefile", 
             "config/hoe.rb", 
             "config/requirements.rb", 
             "lib/ec2onrails.rb", 
             "lib/ec2onrails/capistrano_utils.rb", 
             "lib/ec2onrails/recipes.rb", 
             "lib/ec2onrails/version.rb", 
             "log/debug.log", 
             "script/destroy", 
             "script/generate", 
             "script/txt2html", 
             "setup.rb", 
             "tasks/deployment.rake", 
             "tasks/environment.rake", 
             "tasks/website.rake", 
             "test/test_ec2onrails.rb", 
             "test/test_helper.rb", 
             "website/index.html", 
             "website/index.txt", 
             "website/javascripts/rounded_corners_lite.inc.js", 
             "website/stylesheets/screen.css", 
             "website/template.rhtml", 
             "test/test_app/test/test_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://ec2onrails.rubyforge.org}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ec2onrails}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Client-side libraries (Capistrano tasks) for managing and deploying to EC2 on Rails servers.}
  s.test_files = ["test/test_app/test/test_helper.rb", "test/test_ec2onrails.rb", "test/test_helper.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<capistrano>, ["= 2.4.3"])
      s.add_runtime_dependency(%q<archive-tar-minitar>, [">= 0.5.1"])
      s.add_runtime_dependency(%q<optiflag>, [">= 0.6.5"])
    else
      s.add_dependency(%q<capistrano>, ["= 2.4.3"])
      s.add_dependency(%q<archive-tar-minitar>, [">= 0.5.1"])
      s.add_dependency(%q<optiflag>, [">= 0.6.5"])
    end
  else
    s.add_dependency(%q<capistrano>, ["= 2.4.3"])
    s.add_dependency(%q<archive-tar-minitar>, [">= 0.5.1"])
    s.add_dependency(%q<optiflag>, [">= 0.6.5"])
  end
end
