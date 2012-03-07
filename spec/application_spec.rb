$: << File.join(File.dirname(__FILE__), '..')

require 'application'
require_relative 'spec_helper'

describe Application do

	describe "is empty" do
		it "should not be valid" do
			subject.valid?.should be_false
		end
	
		it "should not be valid without name" do
			subject.valid?.should be_false
			subject.errors.messages[:name].include?("can't be blank").should be_true
		end
		
		it "should not be valid without url" do
			subject.valid?.should be_false
			subject.errors.messages[:url].include?("can't be blank").should be_true
		end
		
		it "should not be valid without user" do
			subject.valid?.should be_false
			subject.errors.messages[:user_id].include?("can't be blank").should be_true
		end	
	end
	
	
	describe "is not valid" do
		subject do
			app = Application.new
			app.name = "n"
			app.url = "www.test.com"
			app.user_id = "incorrect"
			app
		end

		it "should not be valid" do
			subject.valid?.should be_false
		end
		
		it "should not be valid with too short name" do
			subject.valid?.should be_false
			subject.errors.messages[:name].include?("is invalid").should be_true
		end
		
		it "should not be valid with a wrong name" do
			subject.name = "test faux"
			subject.valid?.should be_false
			subject.errors.messages[:name].include?("is invalid").should be_true
		end
		
		it "should not be valid with a wrong url" do
			subject.valid?.should be_false
			subject.errors.messages[:url].include?("is invalid").should be_true
		end
		
		it "should not be valid with a wrong user_id" do
			subject.valid?.should be_false
			puts "\nerror user_id : #{subject.errors.messages[:user_id].inspect}"
			subject.errors.messages[:user_id].include?("is invalid").should be_true
		end
	end
	
	
	describe "is valid" do
		subject do
			app = Application.new
			app.name = "test_appli"
			app.url = "https://www.test.com"
			app.user_id = "012"
			app
		end
	
		it "should be valid" do
			subject.valid?.should be_true
		end
	end
	
end
