require 'spec_helper'
require 'rack/test'

include Rack::Test::Methods

def app
  Sinatra::Application
  #attr_reader :session
end


describe "accessing the registration page" do
	it "should reach the registration page" do
		get '/sauth/register'
		last_response.status.should == 200
	end
	
	it "should reload the page with wrong parameters (login already exists)" do
		params = {'login' => "toto", 'password' => "tata", "password_confirmation"=>"tata"}
		post '/sauth/conf_register', params
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/register?error=err03"
	end
	
	it "should redirect to a confirmation page" do
		params = {'login' => "tutu", 'password' => "tata", "password_confirmation"=>"tata"}
		post '/sauth/conf_register', params		
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions"
		u = User.find_by_login("tutu")
		User.delete(u.id)
	end
end


describe "accessing the connection page" do
	it "should redirect user to login page" do 
    get '/sauth/sessions'
    last_response.status.should == 302
    last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
    follow_redirect!
    last_response.status.should == 200
  end
  
  it "should redirect to /sessions with good params" do 
		params = {'login' => "toto", 'password' => "toto"}
    post '/sauth/sessions', params
    last_response.status.should == 302
    last_response.headers["Location"].should == "http://example.org/sauth/sessions"
  end
  
  it "should reload the page with wrong params" do 
		params = {'login' => "tutu", 'password' => "tata"}
    post '/sauth/sessions', params
    last_response.status.should == 302
    last_response.headers["Location"].should == "http://example.org/sauth/sessions/new?error=err01"
  end
end


describe "deconnecting" do
	it "should disconnect the user" do
		params = {'login' => "toto", 'password' => "toto"}
		post '/sauth/sessions', params
		last_request.env['rack.session']['current_user'].should == 'toto'
		follow_redirect!
		
		get '/sauth/sessions/disconnect'
		last_request.env['rack.session']['current_user'].should be_nil
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
end


describe "accessing the protected area of an application" do
  describe "without basic authentication and session" do
    it "should redirect to login form" do 
      get '/appli_cliente1/protected'
      follow_redirect!
      last_request.path.should == '/sauth/sessions/new'
    end
  end
end
