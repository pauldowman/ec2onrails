require 'spec'
require "#{File.dirname(__FILE__)}/../../../server/files/usr/local/ec2onrails/lib/s3_helper"

REAL_S3_CONFIG = "#{File.dirname(__FILE__)}/../../../../local/s3.yml"
MOCK_S3_CONFIG = "#{File.dirname(__FILE__)}/../../../documentation/examples/s3.yml"

TEST_FILE_1 = "#{File.dirname(__FILE__)}/../test_files/test1"
TEST_FILE_2 = "#{File.dirname(__FILE__)}/../test_files/test2"

describe Ec2onrails::S3Helper do
  before(:each) do
    FileUtils.rm_f("/tmp/test*")
  end
  
  describe "with a mock connection" do
    before(:each) do
      AWS::S3::Base.stub!(:establish_connection!)
      @s3_helper = Ec2onrails::S3Helper.new("bucket", nil, MOCK_S3_CONFIG, "production")
    end
  
    it "can load S3 config details from a config file with multiple environment sections" do
      @s3_helper.aws_access_key.should == "DEF456"
      @s3_helper.aws_secret_access_key.should == "def456def456def456def456"
      @s3_helper.bucket.should == "yourbucket-bucket"
    end
  
    it "can load S3 config details from a config file with no environment sections" do
      s3 = Ec2onrails::S3Helper.new("bucket", nil, "#{File.dirname(__FILE__)}/s3_old.yml", "production")
      s3.aws_access_key.should == "ABC123"
      s3.aws_secret_access_key.should == "abc123abc123abc123abc123"
      s3.bucket.should == "yourbucket-bucket"
    end
  
    it "can create an s3 key using a given filename" do
      @s3_helper.s3_key(TEST_FILE_1).should == "test1"
    end
  
    it "can create an s3 key using a given filename and a subdir name" do
      @s3_helper = Ec2onrails::S3Helper.new("bucket", "subdir", MOCK_S3_CONFIG, "production")
      @s3_helper.s3_key(TEST_FILE_1).should == "subdir/test1"
    end  
  end

  describe "with a real connection" do
    # Integration tests to make sure we can use the real API
    before(:each) do
      @s3_helper = Ec2onrails::S3Helper.new("ec2onrails-test", nil, REAL_S3_CONFIG, "production")
      begin
        bucket = AWS::S3::Bucket.find(@s3_helper.bucket)
        bucket.delete_all
        # bucket.delete
      rescue AWS::S3::NoSuchBucket
        # no problem
      end
    end
    
    it "can create a bucket" do
      @s3_helper.create_bucket
      AWS::S3::Bucket.find(@s3_helper.bucket)
    end
    
    it "can upload a file to S3" do
      @s3_helper.store_file(TEST_FILE_1)
      AWS::S3::S3Object.find("test1", "ec2onrails-test")
    end
    
    it "can upload a file to S3 into a subdir" do
      @s3_helper = Ec2onrails::S3Helper.new("test", "subdir", REAL_S3_CONFIG, "production")
      @s3_helper.store_file(TEST_FILE_1)
      AWS::S3::S3Object.find("subdir/test1", "ec2onrails-test")
    end
    
    it "can retrieve a file from S3" do
      @s3_helper.store_file(TEST_FILE_1)
      AWS::S3::S3Object.find("test1", "ec2onrails-test")
    end
    
    it "can retrieve a file from S3 into a subdir" do
      @s3_helper = Ec2onrails::S3Helper.new("test", "subdir", REAL_S3_CONFIG, "production")
      @s3_helper.store_file(TEST_FILE_1)
      @s3_helper.retrieve_file("/tmp/test1")
    end
    
    it "can delete files with a given prefix" do
      @s3_helper.store_file(TEST_FILE_1)
      @s3_helper.store_file(TEST_FILE_2)
      AWS::S3::S3Object.find("test1", "ec2onrails-test")
      AWS::S3::S3Object.find("test2", "ec2onrails-test")
      @s3_helper.delete_files("test")
      lambda {
        AWS::S3::S3Object.find("test1", "ec2onrails-test")
      }.should raise_error
      lambda {
        AWS::S3::S3Object.find("test2", "ec2onrails-test")
      }.should raise_error
    end
    
    it "can delete files with a given prefix in a subdir" do
      @s3_helper = Ec2onrails::S3Helper.new("test", "subdir", REAL_S3_CONFIG, "production")
      @s3_helper.store_file(TEST_FILE_1)
      @s3_helper.store_file(TEST_FILE_2)
      AWS::S3::S3Object.find("subdir/test1", "ec2onrails-test")
      AWS::S3::S3Object.find("subdir/test2", "ec2onrails-test")
      @s3_helper.delete_files("test")
      lambda {
        AWS::S3::S3Object.find("subdir/test1", "ec2onrails-test")
      }.should raise_error
      lambda {
        AWS::S3::S3Object.find("subdir/test2", "ec2onrails-test")
      }.should raise_error
    end
      
    it "can retrieve files with a given prefix into a local dir" do
      @s3_helper.store_file(TEST_FILE_1)
      @s3_helper.store_file(TEST_FILE_2)
      AWS::S3::S3Object.find("test1", "ec2onrails-test")
      AWS::S3::S3Object.find("test2", "ec2onrails-test")
      @s3_helper.retrieve_files("test", "/tmp")
      File.exists?("/tmp/test1").should be_true
      File.exists?("/tmp/test2").should be_true
    end
    
    it "can retrieve files with a given prefix in a subdir into a local dir" do
      @s3_helper = Ec2onrails::S3Helper.new("test", "subdir", REAL_S3_CONFIG, "production")
      @s3_helper.store_file(TEST_FILE_1)
      @s3_helper.store_file(TEST_FILE_2)
      AWS::S3::S3Object.find("subdir/test1", "ec2onrails-test")
      AWS::S3::S3Object.find("subdir/test2", "ec2onrails-test")
      @s3_helper.retrieve_files("test", "/tmp")
      File.exists?("/tmp/test1").should be_true
      File.exists?("/tmp/test2").should be_true
    end
  end
end