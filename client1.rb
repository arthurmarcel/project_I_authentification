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
	if get_env.session["current_user_app1"]
		@user = get_env.session["current_user_app1"]
		erb :"client/protected"
	elsif params["opt"]
		options = params["opt"]
		key = OpenSSL::PKey::RSA.new File.read 'priv_keys/app1_priv.pem'
		encoded = Base64.urlsafe_decode64(options)
		decoded = key.private_decrypt encoded
		param = []
		param = decoded.split(';')
		login = param[0]
		secret = param[1]
		
		if login && secret && session["#{secret}"] && (Time.now.to_i - session["#{secret}"]) < 15
			puts "timer : #{session["#{secret}"]}"			
			@user = login
			session["current_user_app1"] = @user
			session["#{secret}"] = nil
			erb :"client/protected"
		else
			erb :"client/protected_failed"
		end
	else
		key = OpenSSL::PKey::RSA.new File.read 'priv_keys/app1_priv.pem'
		var = (0...50).map{ ('a'..'z').to_a[rand(26)] }.join
		crypted = key.private_encrypt "#{var}"
		encoded = Base64.urlsafe_encode64(crypted)
		session["#{var}"] = Time.now.to_i
		redirect "http://localhost:4567/sauth/sessions/new?app=app1&origin=protected&secret=#{encoded}"
	end
end


get '/app1.fr/disconnect' do
	session["current_user_app1"] = nil
	redirect "/app1.fr"
end
