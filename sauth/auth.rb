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
end




get "/sauth/users" do
	if session["current_user"]
		redirect "/sauth/users/#{session["current_user"]}"
	else
		redirect "/sauth/sessions/new"
	end
end




get "/sauth/users/new" do
	if !session["current_user"]
		erb :"register/register"
	else
		redirect "/sauth/users/#{session["current_user"]}"
	end
end




post "/sauth/users" do
	if !session["current_user"]
		@user = User.new({"login"=>params["login"], "password"=>params["password"]})
		@log = params["login"]
		@pass = params["password"]
		@conf = params["password_confirmation"]
		
		if params["password"] == params["password_confirmation"] && @user.save			
			session["current_user"] = @user.login
			
			settings.logger.info("Account creation				#{@user.login}")
			settings.logger.info("[Session]			#{session["current_user"]} disconnected")
			
			redirect "sauth/users/#{@user.login}"
		else		
			erb :"register/register"
		end
	else
		redirect "/sauth/users/#{session["current_user"]}"
	end
end




get "/sauth/users/:login_user" do
	if session["current_user"]
		@user = User.find_by_login(session["current_user"])
		
		if session["current_user"] == params[:login_user]
			@apps_own = @user.find_apps_own
			@apps_linked = @user.find_apps_use
			
			if @user.admin
				@users = User.where(:admin => false)
			end
			
			erb :"sessions/list"
		else
			redirect "/sauth/users/#{session["current_user"]}"
		end
		
	else
		redirect "/sauth/sessions/new"
	end
end




get "/sauth/users/:login/delete" do
	if session["current_user"] 
		@login = params[:login]
		
		if User.find_by_login(@login).admin
			redirect "/sauth/users/#{session["current_user"]}"
			
		elsif (session["current_user"] == @login) || (User.find_by_login(session["current_user"]).admin) 
			user = User.find_by_login(@login)
			deleter = User.find_by_login(session["current_user"])
			
			deleted_uses = user.delete_linked_uses
			deleted_uses.each do |use|
				settings.logger.info("Use deleted				#{use}")
			end
			
			deleted_apps = user.delete_owned_apps
			deleted_apps.each do |a|
				settings.logger.info("Application deleted			#{a}")
			end
	
			
			user.delete
			user.save
			
			settings.logger.info("User deleted					#{user.login}")
			
			@msg = "Account successuly deleted !"
			
			if deleter.admin
				redirect "/sauth/users/#{session["current_user"]}"
			else
				settings.logger.info("[Session]			#{session["current_user"]} disconnected")
				session["current_user"] = nil
				erb :"sessions/new"
			end
			
		else
			erb :"register/err_delete_account"
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
	
	if !session["current_user"]
		if a
			@app = params["app"]
			@origin = params["origin"]
			@secret = params["secret"]
			@msg = "Please log in sauth to access #{params["app"]}"
		end
		erb :"sessions/new"
	else
		if a
			url = find_url_app_redirect(a, params["origin"], params["secret"], session["current_user"])
			
			us = Use.new
			us.user_id = User.find_by_login(session["current_user"]).id
			us.application_id = a.id
			
			if us.save
				settings.logger.info("New use				(#{User.find_by_login(session["current_user"]).login}, #{a.name})")
			end
			
			redirect "#{url}"
		else
			redirect "/sauth/users/#{session["current_user"]}"
		end
	end
end




post "/sauth/sessions" do
	if !session["current_user"]
		if params["app"] && params["origin"] && params["secret"]
			a = Application.find_by_name(params["app"])
			if a.nil?
				halt erb :"appsauth/app_not_registered"
			end
		end
	
		u = User.find_by_login(params["login"])
	
		if u && u.authenticate(params["password"])
			session["current_user"] = u.login
			settings.logger.info("[Session]			#{session["current_user"]} connected")
			
			if a
				url = find_url_app_redirect(a, params["origin"], params["secret"], session["current_user"])
			
				us = Use.new
				us.user_id = User.find_by_login(session["current_user"]).id
				us.application_id = a.id
				
				if us.save
					settings.logger.info("New use				(#{User.find_by_login(session["current_user"]).login}, #{a.name})")
				end
			
				redirect "#{url}"
				
			else
				redirect "/sauth/users/#{u.login}"
			end
			
		else
			if a
				@app = params["app"]
				@origin = params["origin"]
				@secret = params["secret"]
			end
			
			if u
				@login = params["login"]
				@msg = "Error: bad password"
				
			else
				@msg = "Error: user not found"
			end
			
			erb :"sessions/new"
		end
		
	else
		redirect "/sauth/users/#{session["current_user"]}"
	end
end




get "/sauth/sessions/delete" do
	settings.logger.info("[Session]			#{session["current_user"]} disconnected")
	session["current_user"] = nil
	redirect "sauth/sessions/new"
end




get "/sauth/apps/new" do
	if session["current_user"]
		erb :"register/newapp"
	else
		redirect "sauth/sessions/new"
	end
end




post "/sauth/apps" do
	if session["current_user"]	
		uid = User.find_by_login(session["current_user"]).id
		@app = Application.new({"name"=>params["name"], "url"=>params["url"], "pubkey"=>params["pubkey"], "user_id"=>uid})
		
		if @app.save
			settings.logger.info("New application				#{@app.name}")
			redirect "/sauth/users/#{session["current_user"]}"
		else
			erb :"register/newapp"
		end
		
	else
		redirect "sauth/sessions/new"
	end
end




get "/sauth/apps/:app_name/delete" do
	if session["current_user"]
		@user = User.find_by_login(session["current_user"])
		app = Application.find_by_name(params[:app_name])
		
		if app		
			if app.user_id == @user.id || @user.admin
				
				deleted_uses = app.delete_linked_uses
				deleted_uses.each do |use|
					settings.logger.info("Use deleted				#{use}")
				end
				
				app.delete
				app.save
				settings.logger.info("Application deleted			#{app.name}")
				
			else
				@error = "Error: This application is not yours"
			end
			
		else
			@error = "Error: This application doesn't exist"
		end
		
		@apps_own = @user.find_apps_own
		@apps_linked = @user.find_apps_use
		
		if @user.admin
			@users = User.where(:admin => false)
		end
		
		erb :"sessions/list"
		
	else
		redirect "sauth/sessions/new"
	end
end




get "/sauth/uses/:app_name/delete" do
	if session["current_user"]
		@user = User.find_by_login(session["current_user"])	
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
			@users = User.where(:admin => false)
		end
		
		erb :"sessions/list"
	else
		redirect "sauth/sessions/new"
	end
end

