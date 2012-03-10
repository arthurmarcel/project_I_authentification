$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'rack/test'
require 'rspec'
require 'active_record'
require_relative '../client1'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe "accessing the index" do
	it "should reach the index page" do
		get '/app1.fr'
		last_response.status.should == 200
	end
end
