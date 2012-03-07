$: << File.join(File.dirname(__FILE__), '..')

require 'user'
require_relative 'spec_helper'

describe User do

	describe "not complete" do
		it "should not be valid if empty" do
			subject.valid?.should be_false
		end

		it "should not be valid without login" do
			subject.valid?.should be_false
			subject.errors.messages[:login].include?("can't be blank").should be_true
		end

		it "should not be valid without password" do
			subject.valid?.should be_false
			subject.errors.messages[:password].include?("can't be blank").should be_true
		end

		it "should not be valid without password confirmation" do
			subject.valid?.should be_false
			subject.errors.messages[:password_confirmation].include?("can't be blank").should be_true
		end
	end
	

	describe "login is incorrect" do
		subject do
			u = User.new
			u.login = "%test@"
			u.password = "password"
			u
		end

		it "should not be valid with incorrect login" do
			subject.valid?.should be_false
			subject.errors.messages[:login].include?("is invalid").should be_true
		end

		it "should not be valid with too short login" do
			subject.login = "too"
			subject.valid?.should be_false
			subject.errors.messages[:login].include?("is invalid").should be_true
		end
	end


	describe "password tests" do
		subject do
			u = User.new
			u.login = "login"
			u
		end

		it "should encrypt the password with sha1" do
			Digest::SHA1.should_receive(:hexdigest).with("password").and_return("5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8")
			Digest::SHA1.should_receive(:hexdigest).with("password").and_return("5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8")
			subject.password = "password"
			subject.password.should == "5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8"
		end

		it "should have stored the encrypted password" do
			subject.password = "password"
			subject.password.should == User.encode_pass("password")
		end

		it "should not be valid with a different password_confirmation" do
			subject.password = "password"
			subject.password_confirmation = "other"
			subject.valid?.should be_false
		end

		it "should be valid with the same password_confirmation" do
			subject.password = "password"
			subject.password_confirmation = "password"
			subject.valid?.should be_true
		end
	end


	describe "is valid" do
		subject do
			u = User.new
			u.login = "login"
			u.password = "password"
			u.password_confirmation = "password"
			u
		end

		it "should be valid" do
			subject.valid?.should be_true
		end
	end

end
