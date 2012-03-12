require 'active_record'
require_relative 'lib/user'
require_relative 'lib/application'
require_relative 'lib/use'
require 'sinatra'
require_relative 'env/env'
require "base64"

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
		secret = params["secret"]
		key = OpenSSL::PKey::RSA.new File.read 'priv_keys/app1_priv.pem'
		encoded = Base64.urlsafe_decode64(encoded)
		@user = key.private_decrypt params["secret"]
		session["current_user_app1"] = @user
		erb :"client/protected"
	else
		redirect 'http://localhost:4567/sauth/sessions/new?app=app1&origin=protected'
	end
end
