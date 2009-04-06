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

require 'spec'
require "#{File.dirname(__FILE__)}/../../../server/files/usr/local/ec2onrails/lib/system_files_manifest"

TEST_FILES_ROOT = "#{File.dirname(__FILE__)}/../test_files"

describe Ec2onrails::SystemFilesManifest do
  before(:each) do
    Ec2onrails::SystemFilesManifest.stub!(:log_error)
  end
  
  describe "with a valid directory that matches the manifest" do
    before(:each) do
      @dir = File.join TEST_FILES_ROOT, "system_files1"
    end

    it "can construct a new object from the directory" do
      Ec2onrails::SystemFilesManifest.new @dir
    end
    
    it "can construct a new object given the manifest file name" do
      Ec2onrails::SystemFilesManifest.new "#{@dir}/#{Ec2onrails::SystemFilesManifest::MANIFEST_FILE_NAME}"
    end
    
    it "recognizes the format of comment and empty lines" do
      m = Ec2onrails::SystemFilesManifest.new(@dir)
      m.comment_or_empty_line?("").should be_true
      m.comment_or_empty_line?(" ").should be_true
      m.comment_or_empty_line?("  ").should be_true
      m.comment_or_empty_line?("\t  ").should be_true
      m.comment_or_empty_line?("#").should be_true
      m.comment_or_empty_line?(" #").should be_true
      m.comment_or_empty_line?("\t#").should be_true
      m.comment_or_empty_line?(" #xx  ").should be_true
      m.comment_or_empty_line?(" #xx  #  ").should be_true
      
      m.comment_or_empty_line?(" x#  ").should be_false
      m.comment_or_empty_line?(" x#xx  ").should be_false
      m.comment_or_empty_line?("x#").should be_false
    end
    
    it "can provide metadata about the mode and owner of the file" do
      m = Ec2onrails::SystemFilesManifest.new @dir
      m["test1"].should == {:mode => nil, :owner => nil}
      m["test2"].should == {:mode => "777", :owner => "user1:user1"}
      m["testfolder"].should == {:mode => nil, :owner => nil}
      m["testfolder/test3"].should == {:mode => "700", :owner => "user2"}
    end

    it "can provide metadata about the file even if the filename has a leading slash appended" do
      m = Ec2onrails::SystemFilesManifest.new @dir
      m["/test1"].should == {:mode => nil, :owner => nil}
    end

    it "can provide metadata about the file even if the filename has the full server_files dir path appended" do
      m = Ec2onrails::SystemFilesManifest.new @dir
      m["#{@dir}/test1"].should == {:mode => nil, :owner => nil}
    end
    
    it "can normalize a given filename by removing the directories up to and including the server_files dir, and removing the leading slash" do
      m = Ec2onrails::SystemFilesManifest.new @dir
      m.normalize("test").should == "test"
      m.normalize("/test").should == "test"
      m.normalize("#{@dir}/test").should == "test"
      m.normalize("#{@dir}/x/test").should == "x/test"
    end
    
    it "can return all filenames as an array" do
      m = Ec2onrails::SystemFilesManifest.new @dir
      m.filenames.should == %w(test1 test2 testfolder testfolder/test3)
    end
  end

  describe "with a valid directory that doesn't match the manifest" do
    before(:each) do
      @dir = File.join TEST_FILES_ROOT, "system_files2"
      
    end
    
    it "should raise an error on new" do
      lambda {Ec2onrails::SystemFilesManifest.new @dir}.should raise_error
    end
  end
  
  describe "with a valid directory that contains no manifest" do
    before(:each) do
      @dir = File.join TEST_FILES_ROOT
    end

    it "should raise an error on new" do
      lambda {Ec2onrails::SystemFilesManifest.new @dir}.should raise_error
    end
  end
  
  describe "with an invalid directory" do
    before(:each) do
      @dir = "does_not_exist"
    end
    
    it "should raise an error on new" do
      lambda {Ec2onrails::SystemFilesManifest.new @dir}.should raise_error
    end
  end
end

