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
	@login = ""
	@password = ""
	@errors = nil
	erb :"register/register", :locals => {:error=>""}
end


post '/sauth/conf_register' do
	u = User.new
	u.login = params["login"]
	u.password = params["password"]
	
	if params["password"] != params["password_confirmation"]
		@errors = {:password_confirmation => ["is not the smae as password"]}
		erb :"register/register"
	elsif u.valid?
		u.save
		session["current_user"] = "#{u.login}"
		redirect '/sauth/sessions'
		#erb :"register/conf_register", :locals => {:user=>u.login}
	else
		@errors = u.errors.messages
		if u.errors.messages[:password] && u.errors.messages[:password].include?("can't be blank")
			u.errors.messages[:password].push("must be an alphanumeric string between 4 and 20 characters")
		end
		erb :"register/register"
	end
end


get '/appli_cliente1/protected' do
	redirect '/sauth/sessions/new'
end


get '/sauth/sessions' do
	if session["current_user"]
		#puts "session user : #{session["current_user"]}"
		@login = session["current_user"]
		erb :"sessions/list"
	else
		redirect '/sauth/sessions/new'
	end
end


get '/sauth/sessions/new' do
	erb :"sessions/new", :locals => {:error=>""}
end


post '/sauth/sessions' do
	u = User.find_by_login(params["login"])
	
	if u && (u.password == User.encode_pass(params["password"]))
		session["current_user"] = "#{u.login}"
		redirect '/sauth/sessions'
	else
		erb :"sessions/new", :locals => {:error=>"Error: user not found or bad password"}
	end
end


get '/sauth/sessions/disconnect' do
	session["current_user"] = nil
	redirect 'sauth/sessions/new'
end
