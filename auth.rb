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
		erb :"register/register", :locals => {:error=>"Error: login already exists or incorrect login/password"}
	else
		erb :"register/register", :locals => {:error=>""}
	end
end

post '/sauth/conf_register' do
	u = User.new
	u.login = params["login"]
	u.password = params["password"]
	u.password_confirmation = params["password_confirmation"]
	
	if u.valid?
		u.save
		erb :"register/conf_register", :locals => {:user=>u.login}
	else	
		redirect '/sauth/register?error=err01'
	end
end

get '/appli_cliente1/protected' do
	redirect '/sauth/sessions/new'
end

get '/sauth/sessions' do
	if session["current_user"]
		puts "session user : #{session["current_user"]}"
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
