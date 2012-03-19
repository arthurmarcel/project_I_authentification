$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'rack/test'
require 'rspec'
require_relative '../client2'

include Rack::Test::Methods

def app
  Sinatra::Application
end


describe "accessing the index" do
	it "should reach the index page" do
		get '/app2.fr'
		last_response.status.should == 200
	end
	
	it "should display the index page" do
		get '/app2.fr'
		last_response.body.should match %r{<div.*class="index".*}
	end
end


describe "accessing the protected area" do
	it "should reach the protected area if logged" do
		e = double('Env')
		Env.stub(:new){e}
		e.stub("session="){}
		e.stub("session"){{"current_user_app2" => "toto"}}
		
		get '/app2.fr/protected'
		last_response.status.should == 200
		last_response.body.should match %r{<div.*class="protected".*}
	end
	
	it "should redirect to sauth login if not logged" do
		get '/app2.fr/protected'
		last_response.status.should == 302
		last_response.headers["Location"].should match %r{.+/sauth/sessions/new.*}
	end
end
