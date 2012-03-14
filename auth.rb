require 'active_record'
require_relative 'lib/user'
require_relative 'lib/application'
require_relative 'lib/use'
require 'sinatra'
require 'openssl'
require "base64"

#set :show_exceptions, false

config_file = File.join(File.dirname(__FILE__),"config","database.yml")

puts YAML.load(File.open(config_file)).inspect

base_directory = File.dirname(__FILE__)
configuration = YAML.load(File.open(config_file))["authentification"]
configuration["database"] = File.join(base_directory, configuration["database"])

ActiveRecord::Base.establish_connection(configuration)

enable :sessions

get '/sauth/register' do
	erb :"register/register"
end


post '/sauth/conf_register' do
	u = User.new
	u.login = params["login"]
	u.password = params["password"]
	
	if u.valid? && params["password"] == params["password_confirmation"]
		u.save
		session["current_user"] = "#{u.login}"
		redirect '/sauth/sessions'
	else
		@errors = u.errors.messages
		
		if params["password"] != params["password_confirmation"]
			@errors[:password_confirmation] = []
			@errors[:password_confirmation].push("is not the same as password")
		end
		
		if u.errors.messages[:password] && u.errors.messages[:password].include?("can't be blank")
			@errors[:password].push("must be an alphanumeric string between 4 and 20 characters")
		end
				
		if !@errors[:password] && !@errors[:password_confirmation]
			@password = params["password"]
			@password_confirmation = params["password_confirmation"]
		end
		
		if !@errors[:login]
			@login = params["login"]
		end
		
		erb :"register/register"
	end
end


get '/sauth/sessions' do
	session["delte_confirm"] = nil
	if session["current_user"]
		#puts "session user : #{session["current_user"]}"
		@login = session["current_user"]
		erb :"sessions/list"
	else
		redirect '/sauth/sessions/new'
	end
end


get '/sauth/sessions/new' do
	if !params["app"].nil? && !params["origin"].nil?
		a = Application.find_by_name(params["app"])
		if a.nil?
			halt erb :"appsauth/app_not_registered"
		end
	end
	
	if session["current_user"].nil?
		if a
			@app = params["app"]
			@origin = params["origin"]
			@msg = "Please log in sauth to access #{params["app"]}"
		end
		erb :"sessions/new"
	else
		if a
			url = a.url
			key = OpenSSL::PKey::RSA.new(a.pubkey)
			public_encrypted = key.public_encrypt "#{session["current_user"]}"
			encoded = Base64.urlsafe_encode64(public_encrypted)
			
			us = Use.new
			us.user_id = User.find_by_login(session["current_user"]).id
			us.application_id = a.id
			if us.valid?
				us.save
			end
			
			redirect "#{a.url}/#{params["origin"]}?secret=#{encoded}"
		else
			redirect '/sauth/sessions'
		end
	end
end


post '/sauth/sessions' do
	if !params["app"].nil? && !params["origin"].nil?
		a = Application.find_by_name(params["app"])
		if a.nil?
			halt erb :"appsauth/app_not_registered"
		end
	end
	
	u = User.find_by_login(params["login"])
	
	if u && (u.password == User.encode_pass(params["password"]))
		session["current_user"] = "#{u.login}"
		if a
			url = a.url
			#puts "URL : #{url}"
			key = OpenSSL::PKey::RSA.new(a.pubkey)
			public_encrypted = key.public_encrypt "#{session["current_user"]}"
			encoded = Base64.urlsafe_encode64(public_encrypted)
			
			us = Use.new
			us.user_id = u.id
			us.application_id = a.id
			if us.valid?
				us.save
			end
			
			redirect "#{url}/#{params["origin"]}?secret=#{encoded}"
		else
			redirect '/sauth/sessions'
		end
	else
		if a
			@app = params["app"]
			@origin = params["origin"]
		end
		if u
			@login = params["login"]
			@msg = "Error: bad password"
		else
			@msg = "Error: user not found"
		end
		erb :"sessions/new"
	end
end


get '/sauth/sessions/disconnect' do
	session["current_user"] = nil
	redirect 'sauth/sessions/new'
end


get '/sauth/newapp' do
	if session["current_user"]
		erb :"register/newapp"
	else
		redirect 'sauth/sessions/new'
	end
end


post '/sauth/conf_newapp' do
	if session["current_user"]
		app = Application.new
		app.name = params["name"]
		app.url = params["url"]
		app.pubkey = params["pubkey"]
		#puts "PUB : #{app.pubkey_before_type_cast}"
		app.user_id = User.find_by_login(session["current_user"]).id
	
		if app.valid?
			app.save
			redirect '/sauth/sessions'
		else
			@errors = app.errors.messages
			
			if !app.errors.messages[:name]
				@name = params["name"]
			end
			
			if !app.errors.messages[:url]
				@url = params["url"]
			end
			
			if !app.errors.messages[:pubkey]
				@pubkey = params["pubkey"]
			end
			
			erb :"register/newapp"
		end
	else
		redirect 'sauth/sessions/new'
	end
end


get "/sauth/deleteapp" do
	if session["current_user"]
		@login = session["current_user"]
		app = Application.find_by_id(params["app"])
		user = User.find_by_login(session["current_user"])
		if !app.nil?
			if app.user_id != user.id
				@error = "Error: This application is not yours"
				erb :"sessions/list"
			else
				uses = Use.where(:application_id => app.id)
				uses.each do |u|
					u.delete
					u.save
				end
				
				app.delete
				app.save
				erb :"sessions/list" 
			end
		else
			@error = "Error: This application doesn't exist"
			erb :"sessions/list"
		end
	else
		redirect 'sauth/sessions/new'
	end
end


get '/sauth/delete' do
	if session["current_user"]
		if session["delte_confirm"] && session["delte_confirm"] == "OK"
			user = User.find_by_login(session["current_user"])
		
			uses = Use.where(:user_id => user.id)
			uses.each do |u|
						u.delete
						u.save
			end
		
			apps = Application.where(:user_id => user.id)
			apps.each do |a|
						a.delete
						a.save
			end
			
			user.delete
			user.save
		
			session["current_user"] = nil
			session["delte_confirm"] = nil
			
			@msg = "Account successuly deleted !"
			erb :"sessions/new"
		else
			session["delte_confirm"] = "OK"
			erb :"register/delete_account"
		end
	else
		erb :"sessions/new"
	end
end

