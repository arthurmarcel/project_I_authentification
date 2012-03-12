require 'active_record'
require_relative 'lib/user'
require_relative 'lib/application'
require_relative 'lib/use'
require 'sinatra'
require_relative 'env/env'

config_file = File.join(File.dirname(__FILE__),"config","database.yml")

puts YAML.load(File.open(config_file)).inspect

base_directory = File.dirname(__FILE__)
configuration = YAML.load(File.open(config_file))["authentification"]
configuration["database"] = File.join(base_directory, configuration["database"])

ActiveRecord::Base.establish_connection(configuration)

set :port, 5678

enable :sessions


helpers do
	def get_env
		e = Env.new
		e.session = session
		return e
	end
end


get '/app1.fr' do
	@app = "app1"
	erb :"client/index"
end


get '/app1.fr/protected' do
	if !get_env.session["current_user_app1"].nil?
		@user = get_env.session["current_user_app1"]
		erb :"client/protected"
	elsif !params["secret"].nil?
		@user = params["secret"]
		session["current_user_app1"] = params["secret"]
		erb :"client/protected"
	else
		redirect 'http://localhost:4567/sauth/sessions/new?app=http://localhost:5678/app1.fr/protected'
	end
end
