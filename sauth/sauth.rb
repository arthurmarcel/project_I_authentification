require 'active_record'
require_relative 'lib/user'
require_relative 'lib/application'
require_relative 'lib/use'
require 'sinatra'
require 'openssl'
require "base64"
require 'logger'

#set :show_exceptions, false

set :logger , Logger.new('log/sauth_log.log', 'weekly')
set :public_folder, File.dirname(__FILE__) + '/www'

config_file = File.join(File.dirname(__FILE__),"config","database.yml")

puts YAML.load(File.open(config_file)).inspect

base_directory = File.dirname(__FILE__)
configuration = YAML.load(File.open(config_file))["authentification"]
configuration["database"] = File.join(base_directory, configuration["database"])

ActiveRecord::Base.establish_connection(configuration)


unless ENV['RACK_ENV'] == 'test'
	use Rack::Session::Cookie,
		:key => 'rack.session',
		:path => '/',
		:expire_after => 900
end



helpers do
	def find_url_app_redirect(app, origin, first_sec_encoded, new_sec_decoded)			
		key = OpenSSL::PKey::RSA.new(app.pubkey)
		
		first_sec_decoded = Base64.urlsafe_decode64(first_sec_encoded)
		first_sec_decrypted = key.public_decrypt "#{first_sec_decoded}"
		
		secret = "#{new_sec_decoded};#{first_sec_decrypted}"
		public_encrypted = key.public_encrypt "#{secret}"
		encoded = Base64.urlsafe_encode64(public_encrypted)
		
		url = "#{app.url}/#{origin}?opt=#{encoded}"
		return url
	end
	
	def connected
		return !session["current_user"].nil?
	end
	
	def current_user
		return session["current_user"]
	end
	
	def connect(login)
		session["current_user"] = login
	end
	
	def disconnect
		session["current_user"] = nil
	end
end




get "/sauth/users" do
	if connected
		redirect "/sauth/users/#{current_user}"
	else
		redirect "/sauth/sessions/new"
	end
end




get "/sauth/users/new" do
	if connected
		redirect "/sauth/users/#{current_user}"
	else
		erb :"users/register"
	end
end




post "/sauth/users" do
	if connected
		redirect "/sauth/users/#{current_user}"
	else
		@user = User.new({"login"=>params["login"], "password"=>params["password"]})
		@log = params["login"]
		@pass = params["password"]
		@conf = params["password_confirmation"]
		
		if params["password"] == params["password_confirmation"] && @user.save			
			connect(@user.login)
			
			settings.logger.info("Account creation				#{@user.login}")
			settings.logger.info("[Session]			#{current_user} disconnected")
			
			redirect "sauth/users/#{@user.login}"
		else		
			erb :"users/register"
		end
	end
end




get "/sauth/users/:login_user" do
	if connected
		@user = User.find_by_login(current_user)
		
		if current_user == params[:login_user]
			@apps_own = @user.find_apps_own
			@apps_linked = @user.find_apps_use
			
			if @user.admin
				@users = User.find(:all)
			end
			
			erb :"users/list"
		else
			redirect "/sauth/users/#{current_user}"
		end
		
	else
		redirect "/sauth/sessions/new"
	end
end




get "/sauth/users/:login/delete" do
	if connected
		@login_to_delete = params[:login]
		
		if	!User.find_by_login(@login_to_delete)
			redirect "/sauth/users/#{current_user}"
			
		elsif User.find_by_login(@login_to_delete).admin
			redirect "/sauth/users/#{current_user}"
			
		elsif (current_user == @login_to_delete) || (User.find_by_login(current_user).admin) 
			user = User.find_by_login(@login_to_delete)
			deleter = User.find_by_login(current_user)
			
			user.delete_complete(settings.logger)
			
			@msg = "Account successuly deleted !"
			
			if deleter.admin
				redirect "/sauth/users/#{current_user}"
			else
				settings.logger.info("[Session]			#{current_user} disconnected")
				disconnect
				erb :"sessions/new"
			end
			
		else
			erb :"users/err_delete_account"
		end
		
	else
		erb :"sessions/new"
	end
end




get "/sauth/sessions/new" do
	if params["app"] && params["origin"] && params["secret"]
		a = Application.find_by_name(params["app"])
		if a.nil?
			halt erb :"appsauth/app_not_registered"
		end
	end
	
	if !connected
		if a
			@app = params["app"]
			@origin = params["origin"]
			@secret = params["secret"]
			@msg = "Please log in sauth to access #{params["app"]} protected area"
		end
		erb :"sessions/new"
	else
		if a
			url = find_url_app_redirect(a, params["origin"], params["secret"], current_user)
			
			us = Use.new
			us.user_id = User.find_by_login(current_user).id
			us.application_id = a.id
			
			if us.save
				settings.logger.info("New use				(#{User.find_by_login(current_user).login}, #{a.name})")
			end
			
			redirect "#{url}"
		else
			redirect "/sauth/users/#{current_user}"
		end
	end
end




post "/sauth/sessions" do
	if !connected
		if params["app"] && params["origin"] && params["secret"]
			a = Application.find_by_name(params["app"])
			if a.nil?
				halt erb :"appsauth/app_not_registered"
			end
		end
	
		ret = User.authenticate(params["login"], params["password"])
	
		if ret[:ok]
			connect(params["login"])
			settings.logger.info("[Session]			#{current_user} connected")
			
			if a
				url = find_url_app_redirect(a, params["origin"], params["secret"], current_user)
			
				us = Use.new
				us.user_id = User.find_by_login(current_user).id
				us.application_id = a.id
				
				if us.save
					settings.logger.info("New use				(#{User.find_by_login(current_user).login}, #{a.name})")
				end
			
				redirect "#{url}"
				
			else
				redirect "/sauth/users/#{current_user}"
			end
			
		else
			if a
				@app = params["app"]
				@origin = params["origin"]
				@secret = params["secret"]
			end
			
			@errors = ret[:errs]
			
			if !@errors[:login]
				@login = params["login"];
			end
			
			erb :"sessions/new"
		end
		
	else
		redirect "/sauth/users/#{current_user}"
	end
end




get "/sauth/sessions/delete" do
	settings.logger.info("[Session]			#{current_user} disconnected")
	disconnect
	redirect "sauth/sessions/new"
end




get "/sauth/apps/new" do
	if connected
		erb :"applications/newapp"
	else
		redirect "sauth/sessions/new"
	end
end




post "/sauth/apps" do
	if connected
		uid = User.find_by_login(current_user).id
		@app = Application.new({"name"=>params["name"], "url"=>params["url"], "pubkey"=>params["pubkey"], "user_id"=>uid})
		
		if @app.save
			settings.logger.info("New application				#{@app.name}")
			redirect "/sauth/users/#{current_user}"
		else
			erb :"applications/newapp"
		end
		
	else
		redirect "sauth/sessions/new"
	end
end




get "/sauth/apps/:app_name/delete" do
	if connected
		@user = User.find_by_login(current_user)
		app = Application.find_by_name(params[:app_name])
		
		if app		
			if app.user_id == @user.id || @user.admin
				app.delete_complete(settings.logger)
			else
				@error = "Error: This application is not yours"
			end
			
		else
			@error = "Error: This application doesn't exist"
		end
		
		@apps_own = @user.find_apps_own
		@apps_linked = @user.find_apps_use
		
		if @user.admin
			@users = User.find(:all)
		end
		
		erb :"users/list"
		
	else
		redirect "sauth/sessions/new"
	end
end




get "/sauth/uses/:app_name/delete" do
	if connected
		@user = User.find_by_login(current_user)	
		app = Application.find_by_name(params["app_name"])
		
		if app
		
			us = Use.find_by_user_id_and_application_id(@user.id, app.id)	
			if us
				us.delete
				us.save
				settings.logger.info("Use deleted				(#{@user.login}, #{app.name})")
				
			else
				@error = "Error: This application is not linked to your account"
			end
			
		else
			@error = "Error: This application doesn't exist"
		end
		
		@apps_own = @user.find_apps_own
		@apps_linked = @user.find_apps_use
		
		if @user.admin
			@users = User.find(:all)
		end
		
		erb :"users/list"
	else
		redirect "sauth/sessions/new"
	end
end

