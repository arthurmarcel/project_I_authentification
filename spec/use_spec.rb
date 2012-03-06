$: << File.join(File.dirname(__FILE__), '..')

require 'use'
require_relative 'spec_helper'

describe Use do

	describe "is empty" do
		it "should not be valid" do
			subject.valid?.should be_false
		end
	
		it "should not be valid without user_id" do
			subject.valid?.should be_false
			subject.errors.messages[:user_id].include?("can't be blank").should be_true
		end
		
		it "should not be valid without application_id" do
			subject.valid?.should be_false
			subject.errors.messages[:application_id].include?("can't be blank").should be_true
		end
	end
	
	describe "is invalid" do
		subject do
			u = Use.new
			u.user_id = "testFauxUser"
			u.application_id = "testFauxApp"
			u
		end
		
		it "should not be valid" do
			subject.valid?.should be_false
		end
	
		it "should not be valid without user_id" do
			subject.valid?.should be_false
			subject.errors.messages[:user_id].include?("is invalid").should be_true
		end
		
		it "should not be valid without application_id" do
			subject.valid?.should be_false
			subject.errors.messages[:application_id].include?("is invalid").should be_true
		end
	end
	
	describe "is valid" do
		subject do
			u = Use.new
			u.user_id = "0123"
			u.application_id = "4567"
			u
		end
		
		it "should be valid" do
			subject.valid?.should be_true
		end
	end
	
end
