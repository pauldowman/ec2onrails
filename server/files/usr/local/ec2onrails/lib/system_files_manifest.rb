#    This file is part of EC2 on Rails.
#    http://rubyforge.org/projects/ec2onrails/
#
#    Copyright 2007 Paul Dowman, http://pauldowman.com/
#
#    EC2 on Rails is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    EC2 on Rails is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Ec2onrails
  class SystemFilesManifest
    
    MANIFEST_FILE_NAME = "_manifest"
    
    # dir is expected to contain a file named MANIFEST_FILE_NAME
    def initialize(dir_or_file)
      if File.directory?(dir_or_file)
        @dir = dir_or_file
        @file = File.join @dir, MANIFEST_FILE_NAME
        raise "Can't find manifest file: #{@file}" unless File.exists?(@file)
        @entries = parse(@file)      
        raise "Manifest doesn't match entries in #{@dir}" unless validate
      else
        @dir = nil
        @file = dir_or_file
        raise "Can't find manifest file: #{@file}" unless File.exists?(@file)
        @entries = parse(@file)
      end
    end

    # Check that the manifest entries match the files in the given directory
    def validate
      errors = false
      # make sure there's a file for each manifest entry
      @entries.each_key do |filename|
        unless filename == MANIFEST_FILE_NAME
          file = File.join(@dir, filename)
          unless File.exist?(file)
            log_error "File doesn't exist: #{file}"
            errors = true
          end
        end
      end
      
      # make sure there's a manifest entry for each file
      Dir.glob("#{@dir}/**/*").each do |f|
        f = normalize(f)
        unless self[f] || f == MANIFEST_FILE_NAME
          log_error "File isn't listed in manifest: #{f}"
          errors = true
        end
      end
      
      return !errors
    end

    # Return the metadata for the given file
    def [](filename)
      filename = normalize(filename)
      @entries[filename]
    end
   
    def normalize(filename)
      return nil unless filename
      filename = filename.sub(/#{@dir}/, '') if @dir
      filename.sub(/^\//, '')
    end
    
    def comment_or_empty_line?(line)
      !!(line =~ /^\s*((#.*)|\s*)$/)
    end
    
    def parse(file)
      entries = {}
      contents = File.readlines(file)
      contents.each do |line|
        unless comment_or_empty_line?(line)
          filename = line.match(/^([^\s]+)\s*.*$/)[1]
          mode = $1 if line.match(/^.*\s+mode=([^\s]*).*$/)
          owner = $1 if line.match(/^.*\s+owner=([^\s]*).*$/)
          entries[filename] = {:mode => mode, :owner => owner}
        end
      end
      
      return entries
    end
    
    def filenames
      @entries.keys.sort
    end
    
    def self.log_error(message)
      puts message
    end
  end
end

