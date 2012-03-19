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
	
	def find_apps_own(user)
		if user.admin
			return Application.find(:all)
		else
			return Application.where(:user_id => @user.id)
		end
	end
	
	def find_apps_use(user)
		uses = Use.where(:user_id => user.id)
		apps_linked = []
		uses.each do |use|
			apps_linked.push(Application.find_by_id(use.application_id))
		end
		return apps_linked
	end

end



get "/sauth/users/new" do
	erb :"register/register"
end


post "/sauth/users" do
	u = User.new
	u.login = params["login"]
	u.password = params["password"]
	
	if u.valid? && params["password"] == params["password_confirmation"]
		u.save
		session["current_user"] = "#{u.login}"
		redirect "sauth/users/#{u.login}"
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


get "/sauth/users/:login_user" do
	session["delte_confirm"] = nil
	if session["current_user"]
		@user = User.find_by_login(session["current_user"])
		if session["current_user"] == params[:login_user] || @user.admin
			#puts "session user : #{session["current_user"]}"	
			@apps_own = find_apps_own(@user)
			@apps_linked = find_apps_use(@user)
		
			erb :"sessions/list"
		else
			erb :"sessions/errlist"
		end
	else
		redirect "/sauth/sessions/new"
	end
end


get "/sauth/sessions/new" do
	if params["app"] && params["origin"] && params["secret"]
		a = Application.find_by_name(params["app"])
		if a.nil?
			halt erb :"appsauth/app_not_registered"
		end
	end
	
	if session["current_user"].nil?
		if a
			@app = params["app"]
			@origin = params["origin"]
			@secret = params["secret"]
			puts "encode before post :  #{params["secret"]}"
			@msg = "Please log in sauth to access #{params["app"]}"
		end
		erb :"sessions/new"
	else
		if a
			url = find_url_app_redirect(a, params["origin"], params["secret"], session["current_user"])
			
			us = Use.new
			us.user_id = User.find_by_login(session["current_user"]).id
			us.application_id = a.id
			if us.valid?
				us.save
			end
			
			redirect "#{url}"
		else
			redirect "/sauth/users/#{session["current_user"]}"
		end
	end
end


post "/sauth/sessions" do

	if params["app"] && params["origin"] && params["secret"]
		a = Application.find_by_name(params["app"])
		if a.nil?
			halt erb :"appsauth/app_not_registered"
		end
	end
	
	u = User.find_by_login(params["login"])
	
	if u && (u.password == User.encode_pass(params["password"]))
		session["current_user"] = "#{u.login}"
		if a
			url = find_url_app_redirect(a, params["origin"], params["secret"], session["current_user"])
			
			us = Use.new
			us.user_id = User.find_by_login(session["current_user"]).id
			us.application_id = a.id
			if us.valid?
				us.save
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
end


get "/sauth/sessions/delete" do
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
		app = Application.new
		app.name = params["name"]
		app.url = params["url"]
		app.pubkey = params["pubkey"]
		#puts "PUB : #{app.pubkey_before_type_cast}"
		app.user_id = User.find_by_login(session["current_user"]).id
	
		if app.valid?
			app.save
			redirect "/sauth/users/#{session["current_user"]}"
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
		redirect "sauth/sessions/new"
	end
end


get "/sauth/apps/:app_name/delete" do
	if session["current_user"]
		@user = User.find_by_login(session["current_user"])
		app = Application.find_by_name(params[:app_name])
		if app		
			if app.user_id == @user.id || @user.admin
				uses = Use.where(:application_id => app.id)
				uses.each do |use|
					use.delete
					use.save
				end
				app.delete
				app.save
			else
				@error = "Error: This application is not yours"
			end
		else
			@error = "Error: This application doesn't exist"
		end

		@apps_own = find_apps_own(@user)
		@apps_linked = find_apps_use(@user)
		
		erb :"sessions/list"
	else
		redirect "sauth/sessions/new"
	end
end


get "/sauth/users/:login/delete" do
	if session["current_user"] 
		@login = session["current_user"]
		if (User.find_by_login(session["current_user"])).admin
			redirect "/sauth/users/#{session["current_user"]}"
		end
		
		if session["current_user"] == params[:login]
			if session["delete_confirm"] && session["delete_confirm"] == "OK"
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
				session["delete_confirm"] = nil
			
				@msg = "Account successuly deleted !"
				erb :"sessions/new"
			else
				session["delete_confirm"] = "OK"
				erb :"register/delete_account"
			end
		else
			erb :"register/err_delete_account"
		end
	else
		erb :"sessions/new"
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
			else
				@error = "Error: This application is not linked to your account"
			end
		else
			@error = "Error: This application doesn't exist"
		end
		
		@apps_own = find_apps_own(@user)
		@apps_linked = find_apps_use(@user)
		
		erb :"sessions/list"
	else
		redirect "sauth/sessions/new"
	end
end

