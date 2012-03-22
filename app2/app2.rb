require 'sinatra'
require_relative 'env/env'
require "base64"

set :port, 6789

enable :sessions

set :public_folder, File.dirname(__FILE__) + '/www'

helpers do
	def get_env
		e = Env.new
		e.session = session
		return e
	end
end


get '/app2.fr' do
	erb :"client/index"
end


get '/app2.fr/protected' do
	if get_env.session["current_user_app2"]
		@user = get_env.session["current_user_app2"]
		erb :"client/protected"
	elsif params["opt"]
		options = params["opt"]
		key = OpenSSL::PKey::RSA.new File.read 'keys/app2_priv.pem'
		encoded = Base64.urlsafe_decode64(options)
		decoded = key.private_decrypt encoded
		param = []
		param = decoded.split(';')
		login = param[0]
		secret = param[1]
		
		if login && secret && session["#{secret}"] && (Time.now.to_i - session["#{secret}"]) < 15	
			@user = login
			session["current_user_app2"] = @user
			session["#{secret}"] = nil
			erb :"client/protected"
		else
			erb :"client/protected_failed"
		end
	else
		key = OpenSSL::PKey::RSA.new File.read 'keys/app2_priv.pem'
		var = (0...50).map{ ('a'..'z').to_a[rand(26)] }.join
		crypted = key.private_encrypt "#{var}"
		encoded = Base64.urlsafe_encode64(crypted)
		session["#{var}"] = Time.now.to_i
		redirect "http://localhost:4567/sauth/sessions/new?app=app2&origin=protected&secret=#{encoded}"
	end
end


get '/app2.fr/disconnect' do
	session["current_user_app2"] = nil
	redirect "/app2.fr"
end
