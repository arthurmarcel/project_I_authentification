require 'spec_helper'
require 'rack/test'

include Rack::Test::Methods

def app
  Sinatra::Application
end


describe "accessing the registration page" do
	it "should reach the registration page" do
		get '/sauth/users/new'
		last_response.status.should == 200
		last_response.body.should match %r{<form.*action="/sauth/users".*method="post".*}
	end
	
	it "should reload the page with wrong parameters (login already exists)" do
		params = {'login' => "toto", 'password' => "tata", "password_confirmation"=>"tata"}
		post '/sauth/users', params
		last_response.status.should == 200
		last_response.body.should match %r{<form.*action="/sauth/users".*method="post".*}
	end
	
	it "should redirect to a confirmation page" do
		params = {'login' => "tutu", 'password' => "tata", "password_confirmation"=>"tata"}
		post '/sauth/users', params		
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/users/tutu"
		u = User.find_by_login("tutu")
		User.delete(u.id)
	end
end


describe "accessing the connection page" do
	it "should redirect user to login page" do 
    get '/sauth/users/toto'
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
    last_response.headers["Location"].should == "http://example.org/sauth/users/toto"
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
		
		get '/sauth/sessions/delete'
		last_request.env['rack.session']['current_user'].should be_nil
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
end


describe "trying to register an application without being logged" do
	it "should not access the page if not logged (redirect to login page)" do
		get '/sauth/apps/new'
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
	
	it "should not accept to register if not logged (redirect to login page)" do
		post '/sauth/apps'
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
		get '/sauth/apps/new'
		last_response.status.should == 200
		last_response.body.should match %r{<form.*action="/sauth/apps".*method="post".*}
	end
	
	it "should be OK with good parameters" do
		params = {'name' => "app3", 'url' => "http://app3.fr", 'pubkey' => "000000"}
		post '/sauth/apps', params
		#Application.should_receive(:save)
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/users/toto"
		
		a = Application.find_by_name("app3")
		a.delete
		a.save
	end
	
	it "should be KO with wrong parameters (reload form)" do
		params = {'name' => "app1", 'url' => "http://app"}
		post '/sauth/apps', params
		#Application.should_receive(:save)
		last_response.body.should match %r{<form.*action="/sauth/apps".*method="post".*}
	end
end


describe "unregistering an application" do
	it "should not accept to delete the application without being logged" do
		b = Application.find_by_name("app1")
		
		get "/sauth/apps/#{b.name}/delete"
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
	
	it "should accept to delete the application" do
		params = {'login' => "toto", 'password' => "toto"}
		post '/sauth/sessions', params
		last_request.env['rack.session']['current_user'].should == 'toto'
		follow_redirect!
		
		c = Application.find_by_name("app1")
		get "/sauth/apps/#{c.name}/delete"
		last_response.status.should == 200
		
		d = Application.new
		d.name = "app1"
		d.url = "http://localhost:5678/app1.fr"
		d.user_id = 1
		d.pubkey=
		"-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwKVLF2uinWguoYUZLIVd
5C1reIlLte8clvp1KpnCgGX1vYNZ4wN5tRCUN7FcJ/p4TR+xLI9GJX88lhWQNObZ
2Goo5QhvCezg1IMa7M3poCFlS3BisMvHEZtoYRHIM4ayloaStx1DT5Y8/1IyaioW
aD9tjl1AYnzbExWDEjYQwkPgjOwZkUdebxXqKYXRIrmB6PJ4JStxLpvo/Jlrf5ks
8OOmsYXYDy4SHsNmzquPmU3o6nfHYXBBfBlZkIEF6CEku+7VQRfcwaoyxU41CUJ6
fw6o0cwpYN8x7k0k3VMxmFRGh8zqXhRuTvArPvtASGzio3dxBpfMt9vO8iVQ1U17
jQIDAQAB
-----END PUBLIC KEY-----"
		d.save
		
		us = Use.new
		us.user_id = User.find_by_login("toto")
		us.application_id = d.id
		us.save
	end	
end


describe "deleting a link to an application" do
	it "should not accept to delete the use without being logged" do
		a1 = Application.find_by_name("app1")
		get "/sauth/uses/#{a1.name}/delete"
		last_response.status.should == 302
		last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
	end
	
	it "should not accept to delete the use" do
		params = {'login' => "toto", 'password' => "toto"}
		post '/sauth/sessions', params
		last_request.env['rack.session']['current_user'].should == 'toto'
		follow_redirect!
		
		a2 = Application.find_by_name("app1")
		get "/sauth/uses/#{a2.name}/delete"
		last_response.status.should == 200
		
		u2 = User.find_by_login("toto")
		use = Use.new
		use.application_id = a2.id
		use.user_id = u2.id
		use.save
	end
end
