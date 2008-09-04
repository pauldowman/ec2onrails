require 'rubygems'
require 'god'

# this is a hack to put the bin directory back at the top of the load path.... 
# the /usr/bin/god script will try to load 'god', which is in the bin path of the gem
# but is also the name of the module.... it should really be called something like god_bin 
# or god_cli, so then it would have no problem being found.
$:.unshift File.join($:[0], *%w[.. .. bin])

module God
  def self.control(name, command)
    # get the list of items
    items = Array(self.watches[name] || self.groups[name]).dup
    
    jobs = []
    # do the command
    case command
      when "start", "monitor"
        items.each { |w| jobs << Thread.new { w.monitor if w.state != :up } }
      when "restart"
        items.each { |w| jobs << Thread.new { w.move(:restart) } }
      when "stop"
        # items.each { |w| jobs << Thread.new { w.unmonitor.action(:stop) if w.state != :unmonitored } }
        items.each do |w| 
          jobs << Thread.new do
            w.unmonitor if w.state != :unmonitored
            w.action(:stop) if w.alive?
          end
        end
      when "unmonitor"
        items.each { |w| jobs << Thread.new { w.unmonitor if w.state != :unmonitored } }
      when "remove"
        items.each { |w| self.unwatch(w) }
      else
        raise InvalidCommandError.new
    end
    
    jobs.each { |j| j.join }
    
    items.map { |x| x.name }
  end
  
end
