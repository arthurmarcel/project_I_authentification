require 'spec_helper'

describe "sauth service" do

	include Rack::Test::Methods

	def app
		Sinatra::Application
	end


	describe "interacting with users" do
		describe "registering a new user (/sauth/users/new)" do
	  
			describe "asking for registration form" do
				it "should display the form if not logged" do
					get "/sauth/users/new"
					last_response.status.should == 200
					last_response.body.should match %r{<form.*action="/sauth/users".*method="post".*}
				end
			
				it "should redirect to /users/:login user if already logged" do
					 get "/sauth/users/new", {}, "rack.session" => {"current_user" => "toto"}
					 last_response.status.should == 302
					 last_response.headers["Location"].should == "http://example.org/sauth/users/toto"
				end
			end
		
		
			describe "validating the new user" do
				before(:each) do
					@params = {"login" => "toto", "password" => "tata", "password_confirmation"=>"tata"}
					@user = double("user")
					User.stub(:new){@user}
				end
			
				it "should create the user, redirect to the user page and open a session" do
					@user.stub(:save){true}
					@user.stub(:password){"mdp"}
					@user.stub(:login){"toto"}
					@user.stub(:admin){false}
				
					@user.should_receive(:save)
				
					post "/sauth/users", @params
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/users/toto"
				
					last_request.env["rack.session"]["current_user"].should == "toto"
				end
			
				it "should redirect to /users/:login if already logged" do
					post "/sauth/users", @params, "rack.session" => {"current_user" => "titi"}
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/users/titi"
				end
			
				it "should reload the form with wrong parameters" do
					@user.stub(:save){false}
					@user.stub(:get_errs){nil}
				
					post "/sauth/users", @params
					last_response.status.should == 200
					last_response.body.should match %r{<form.*action="/sauth/users".*method="post".*}
				end
			end
		end
		
		
		
		
		describe "deleting a user account" do
			context "logged" do
				before(:each) do				
					@user = double("user")
					@user.stub(:admin){false}
					@user.stub(:id){35000}
					@user.stub(:delete){true}
					@user.stub(:save){true}
					@empty_array = []
					@user.stub(:delete_linked_uses){@empty_array}
					@user.stub(:delete_owned_apps){@empty_array}				
			
					User.stub(:find_by_login){@user}
				end
		
				it "should accept to delete if logged with the good account, then close the session and redirect to /sessions/new" do
					@user.stub(:login){"toto"}
												
					@user.should_receive(:delete)
					@user.should_receive(:save)
							
					get "/sauth/users/toto/delete", {}, "rack.session" => {"current_user" => "toto"}
					last_response.status.should == 200
					last_response.body.should match %r{<form.*action="/sauth/sessions".*method="post".*}
				end
	
				it "should display an error if logged with another account" do
					get "/sauth/users/toto/delete", {}, "rack.session" => {"current_user" => "titi"}
					last_response.status.should == 200
					last_response.body.should match %r{<div.*class="err_delete".*}
				end
			end
	
			context "not logged" do
				it "should redirect to /sessions/new if not logged" do
					get "/sauth/users/toto/delete"
					last_response.status.should == 200
					last_response.body.should match %r{<form.*action="/sauth/sessions".*method="post".*}
				end
			end
		end
	
	
	
	
		describe "accessing personnal page (listing apps)" do
			context "logged" do
				before(:each) do				
					@user = double(User)
					@user.stub(:password){"mdp"}
					@user.stub(:login){"toto"}
					@user.stub(:admin){false}
					@user.stub(:id){1}
					@user.stub(:find_apps_own){nil}
					@user.stub(:find_apps_use){nil}
					User.stub(:find_by_login){@user}
				end
				
				it "should success if logged with good account" do	
					get "/sauth/users/toto", {}, "rack.session" => {"current_user" => "toto"} 
					last_response.body.should match %r{<div.*class="listappown".*}
					last_response.body.should match %r{<div.*class="listappuse".*}
				end
		
				it "should redirect to /sauth/users/:login if logged with another account" do
					get "/sauth/users/toto", {}, "rack.session" => {"current_user" => "titi"} 
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/users/titi"
				end
			end
			
			context "not logged" do
				it "should redirect to /sauth/sessions/new if not logged" do
					get "/sauth/users/toto"
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
				end
			end
		end
	end




	describe "interacting with sessions" do
		describe "openning a new session" do
			it "should display the form if not already logged" do
				get "/sauth/sessions/new"
				last_response.status.should == 200
				last_response.body.should match %r{<form.*action="/sauth/sessions".*method="post".*}
			end
		
			it "should redirect to /sauth/users/:login if already logged and it's not an application request" do
				get "/sauth/sessions/new", {}, "rack.session" => {"current_user" => "toto"} 
				last_response.status.should == 302
				last_response.headers["Location"].should == "http://example.org/sauth/users/toto"
			end
		end
		
		
		
		
		describe "posting a request to open a session" do
			before(:each) do
				@user = double(User)
				@user.stub(:password){"tata"}
				@user.stub(:login){"toto"}
				@user.stub(:authenticate){true}
				User.stub(:find_by_login){@user}
				User.stub(:encode_pass){"tata"}
				@params = {"login" => "toto", "password" => "tata"}
			end
			
			it "should open a session if not logged, and redirect to /sauth/users/:login if it's not an application request" do				
				post "/sauth/sessions", @params
				last_response.status.should == 302
				last_response.headers["Location"].should == "http://example.org/sauth/users/toto"
				last_request.env["rack.session"]["current_user"].should == "toto"
			end
		
			it "should reload the form if errors" do
				@user.stub(:authenticate){false}
				
				post "/sauth/sessions", @params
				last_response.status.should == 200
				last_response.body.should match %r{<form.*action="/sauth/sessions".*method="post".*}
			end
			
			it "should redirect to /sauth/users/:login if already logged" do
				post "/sauth/sessions", @params, "rack.session" => {"current_user" => "titi"} 
				last_response.status.should == 302
				last_response.headers["Location"].should == "http://example.org/sauth/users/titi"
			end
		end
		
		
		
		
		describe "closing a session" do
			it "should redirect to /sauth/sessions/new and close the session" do
				get "/sauth/sessions/delete"
				last_response.status.should == 302
				last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
			end
		end
	end




	describe "interacting with apps" do
		describe "asking for registering a new application" do
			it "should access the page if logged" do
				get '/sauth/apps/new', {}, "rack.session" => {"current_user" => "toto"} 
				last_response.status.should == 200
				last_response.body.should match %r{<form.*action="/sauth/apps".*method="post".*}
			end
			
			it "should not access the page if not logged (redirect to login page)" do
				get '/sauth/apps/new'
				last_response.status.should == 302
				last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
			end
		end
		
		
		
		
		describe "posting a request to register a new application" do
			context "logged" do
				before(:each) do
					@user = double("user")
					@user.stub(:id){35000}
					User.stub(:find_by_login){@user}
					
					@app = double("application")
					Application.stub(:new){@app}
					
					@params = {"name" => "app1", "url" => "http://blabla.fr", "pubkey" => "testkey"}
				end		
	
				it "should create the app with good params and redirect to /sauth/users/:login" do					
					@app.stub(:save){true}
					@app.stub(:name){"app1"}
					@app.should_receive(:save)
					
					post '/sauth/apps', @params, "rack.session" => {"current_user" => "titi"} 
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/users/titi"
				end
	
				it "should fail with wrong parameters and reload form" do
					@app.stub(:save){false}
					@app.stub(:get_errs){nil}
					@app.should_receive(:save)
					
					post '/sauth/apps', @params, "rack.session" => {"current_user" => "titi"} 
					last_response.status.should == 200
					last_response.body.should match %r{<form.*action="/sauth/apps".*method="post".*}
				end
			end
			
			it "should not accept to register if not logged (redirect to login page)" do
				post '/sauth/apps'
				last_response.status.should == 302
				last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
			end
		end
		
		
		
		
		describe "asking for unregistering an application" do	
			context "logged" do
				before(:each) do
					@user = double("user")
					@user.stub(:id){35000}
					@user.stub(:admin){false}
					@user.stub(:login){"toto"}
					@user.stub(:find_apps_own){nil}
					@user.stub(:find_apps_use){nil}
					User.stub(:find_by_login){@user}
					
					@app = double("application")
					Application.stub(:find_by_name){@app}	
				end
				
				it "should accept to delete the application if you own it" do			
					@app.stub(:user_id){35000}
					@app.stub(:id){45000}
					@app.stub(:name){"app1"}
					@app.stub(:delete){true}
					@app.stub(:save){true}
					@empty_array = []
					@app.stub(:delete_linked_uses){@empty_array}					
					
					@app.should_receive(:delete)	
					@app.should_receive(:save)			
					
					get "/sauth/apps/app1/delete", {}, "rack.session" => {"current_user" => "toto"} 
					last_response.status.should == 200
					last_response.body.should match %r{<div.*class="listappown".*}
					last_response.body.should match %r{<div.*class="listappuse".*}
				end	
				
				it "should refuse to delete the application if you don't own it" do						
					@app.stub(:user_id){36000}		
					
					get "/sauth/apps/app1/delete", {}, "rack.session" => {"current_user" => "toto"} 
					last_response.status.should == 200
					last_response.body.should match %r{<div.*class="listappown".*}
					last_response.body.should match %r{<div.*class="listappuse".*}
				end	
				
				it "should refuse to delete the application that does not exist" do			
					Application.stub(:find_by_name){nil}			
					
					get "/sauth/apps/app1/delete", {}, "rack.session" => {"current_user" => "toto"} 
					last_response.status.should == 200
					last_response.body.should match %r{<div.*class="listappown".*}
					last_response.body.should match %r{<div.*class="listappuse".*}
				end	
			end
			
			context "not logged" do
				it "should not accept to delete the application without being logged" do				
					get "/sauth/apps/app1/delete"
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
				end
			end
		end
	end




	describe "interacting with uses" do
		describe "deleting a link between a user and an application" do
			context "logged" do
				before(:each) do
					@user = double("user")
					@user.stub(:id){35000}
					@user.stub(:admin){false}
					@user.stub(:login){"toto"}
					User.stub(:find_by_login){@user}
					
					@app = double("application")
					Application.stub(:find_by_name){@app}	
				end
				
				it "should accept to delete the use if existing" do								
					@app.stub(:id){37000}
						
					@use = double("use")
					@use.stub(:delete){true}
					@use.stub(:save){true}					
					Use.stub(:find_by_user_id_and_application_id){@use}
					
					@use.should_receive(:delete)
					@use.should_receive(:save)
					
					get "/sauth/uses/app2/delete", {}, "rack.session" => {"current_user" => "toto"} 	
				end
			
				it "should not accept to delete the use if the link does not exist" do														
					Use.stub(:find_by_user_id_and_application_id){nil}					
					
					get "/sauth/uses/app2/delete", {}, "rack.session" => {"current_user" => "toto"}
				end
				
				it "should not accept to delete the use if the application does not exist" do														
					Application.stub(:find_by_name){nil}					
					
					get "/sauth/uses/app2/delete", {}, "rack.session" => {"current_user" => "toto"}
				end
			end
				
			context "not logged" do
				it "should not accept to delete the use without being logged" do
					get "/sauth/uses/app1/delete"
					last_response.status.should == 302
					last_response.headers["Location"].should == "http://example.org/sauth/sessions/new"
				end
			end
		end
	end

end
