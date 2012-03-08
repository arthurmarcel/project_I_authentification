require 'active_record'
require_relative 'lib/user'
require_relative 'lib/application'
require_relative 'lib/use'
require 'sinatra'

config_file = File.join(File.dirname(__FILE__),"config","database.yml")

puts YAML.load(File.open(config_file)).inspect

base_directory = File.dirname(__FILE__)
configuration = YAML.load(File.open(config_file))["authentification"]
configuration["database"] = File.join(base_directory, configuration["database"])

ActiveRecord::Base.establish_connection(configuration)

enable :sessions

get '/sauth/register' do
	if params["error"] && params["error"] == "err01"
		erb :"register/register", :locals => {:error=>"Error: password and password confirmation are not the same"}
	elsif params["error"] && params["error"] == "err02"
		erb :"register/register", :locals => {:error=>"Error: login field can't be blank"}
	elsif params["error"] && params["error"] == "err03"
		erb :"register/register", :locals => {:error=>"Error: login has already been taken"}
	elsif params["error"] && params["error"] == "err04"
		erb :"register/register", :locals => {:error=>"Error: unknown error on login"}
	elsif params["error"] && params["error"] == "err05"
		erb :"register/register", :locals => {:error=>"Error: password field can't be blank"}
	elsif params["error"] && params["error"] == "err06"
		erb :"register/register", :locals => {:error=>"Error: unknown error on password"}
	elsif params["error"] && params["error"] == "err07"
		erb :"register/register", :locals => {:error=>"Error: login is not an alphanumeric string between 4 to 20 characters)"}
	else
		erb :"register/register", :locals => {:error=>""}
	end
end


post '/sauth/conf_register' do
	u = User.new
	u.login = params["login"]
	u.password = params["password"]
	#u.password_confirmation = params["password_confirmation"]
	
	if params["password"] != params["password_confirmation"]
		redirect '/sauth/register?error=err01'
	elsif u.valid?
		u.save
		session["current_user"] = "#{u.login}"
		redirect '/sauth/sessions'
		#erb :"register/conf_register", :locals => {:user=>u.login}
	else	
		if u.errors.messages[:login]
			if u.errors.messages[:login].inspect.include?("can't be blank")
				redirect '/sauth/register?error=err02'
			elsif u.errors.messages[:login].inspect.include?("has already been taken")
				redirect '/sauth/register?error=err03'
			elsif u.errors.messages[:login].inspect.include?("is invalid")
				redirect '/sauth/register?error=err07'
			else
				redirect '/sauth/register?error=err04'
			end
		elsif u.errors.messages[:password]
			if u.errors.messages[:password].inspect.include?("can't be blank")
				redirect '/sauth/register?error=err05'
			else
				redirect '/sauth/register?error=err06'
			end
		end
	end
end


get '/appli_cliente1/protected' do
	redirect '/sauth/sessions/new'
end


get '/sauth/sessions' do
	if session["current_user"]
		#puts "session user : #{session["current_user"]}"
		erb :"sessions/list", :locals => {:login=>session["current_user"]}
	else
		redirect '/sauth/sessions/new'
	end
end


get '/sauth/sessions/new' do
	if params["error"] && params["error"] == "err01"
		erb :"sessions/new", :locals => {:error=>"Error: user not found or bad password"}
	else
		erb :"sessions/new", :locals => {:error=>""}
	end
end


post '/sauth/sessions' do
	u = User.find_by_login(params["login"])
	
	if u && (u.password == User.encode_pass(params["password"]))
		session["current_user"] = "#{u.login}"
		redirect '/sauth/sessions'
	else
		redirect '/sauth/sessions/new?error=err01'
	end
end


get '/sauth/sessions/disconnect' do
	session["current_user"] = nil
	redirect 'sauth/sessions/new'
end
