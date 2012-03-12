require 'spec_helper'
require 'rack/test'

include Rack::Test::Methods

def app
  Sinatra::Application
end


describe "accessing the registration page" do
	it "should reach the registration page" do
		get '/sauth/register'
		last_response.status.should == 200
		last_response.body.should match %r{<form.*action="/sauth/conf_register".*method="post".*}
	end
	
	it "should reload the page with wrong parameters (login already exists)" do
		params = {'login' => "toto", 'password' => "tata", "password_confirmation"=>"tata"}
		post '/sauth/conf_register', params
		last_response.status.should == 200
		last_response.body.should match %r{<form.*action="/sauth/conf_register".*method="post".*}
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
    last_response.body.should match %r{<form.*action="/sauth/sessions".*method="post".*}
  end
  
  it "should print the files list with good params" do 
		params = {'login' => "toto", 'password' => "toto"}
    post '/sauth/sessions', params
    last_response.status.should == 302
    last_response.headers["Location"].should == "http://example.org/sauth/sessions"
    follow_redirect!
    last_response.body.should match %r{<div.*class="listappuse".*}
    last_response.body.should match %r{<div.*class="listappown".*}
  end
  
  it "should reload the page with wrong params" do 
		params = {'login' => "tutu", 'password' => "tata"}
    post '/sauth/sessions', params
    last_response.status.should == 200
    last_response.body.should match %r{<form.*action="/sauth/sessions".*method="post".*}
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


describe "trying to register an application without being logged" do
	it "should not access the page if not logged (redirect to login page)" do
		get '/sauth/newapp'
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
	
	it "should not accept to register if not logged (redirect to login page)" do
		post '/sauth/conf_newapp'
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
end


describe "creating an application" do
	before(:each) do
		params = {'login' => "toto", 'password' => "toto"}
		post '/sauth/sessions', params
		last_request.env['rack.session']['current_user'].should == 'toto'
		follow_redirect!
	end
	
	it "should access the page if logged" do
		get '/sauth/newapp'
		last_response.status.should == 200
		last_response.body.should match %r{<form.*action="/sauth/conf_newapp".*method="post".*}
	end
	
	it "should be OK with good parameters" do
		params = {'name' => "app3", 'url' => "http://app3.fr"}
		post '/sauth/conf_newapp', params
		#Application.should_receive(:save)
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions"
		
		a = Application.find_by_name("app3")
		a.delete
		a.save
	end
	
	it "should be KO with wrong parameters (reload form)" do
		params = {'name' => "app1", 'url' => "http://app"}
		post '/sauth/conf_newapp', params
		#Application.should_receive(:save)
		last_response.body.should match %r{<form.*action="/sauth/conf_newapp".*method="post".*}
	end
end


describe "unregistering an application" do
	it "should not accept to delete the application" do
		a = Application.find_by_name("app2")
		
		get "/sauth/deleteapp?app=#{a.id}"
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
	
	it "should accept to delete the application" do
		params = {'login' => "toto", 'password' => "toto"}
		post '/sauth/sessions', params
		last_request.env['rack.session']['current_user'].should == 'toto'
		follow_redirect!
		
		a = Application.find_by_name("app2")
		
		get "/sauth/deleteapp?app=#{a.id}"
		last_response.status.should == 200
		b = Application.new
		b.name = "app2"
		b.url = "http://app2.fr"
		b.user_id = 1
		b.save
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
