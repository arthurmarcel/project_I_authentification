require 'digest/sha1'
require 'active_record'

class User < ActiveRecord::Base

	has_many :applications
	has_many :uses

	######################################
	# Validators
	######################################
		
	# Login
	validates :login, :uniqueness => true
	validates :login, :presence => true
	validates :login, :format => { :with => /^[a-z0-9]{4,20}$/i, :on => :create }

	# Password
	validates :password, :presence => true
	validates :password_confirmation, :presence => true
	validates :password, :confirmation => true

	######################################
	# Class definition
	######################################

	# Accessors
	#def password
		#self[:password]
		#@password
	#end
	
	def password_confirmation
		@password_confirmation
	end
	
	# Encrypt passwords
	def password=(password)
		if !password.nil? && !password.empty?
			@password = User.encode_pass(password)
			self[:password] = User.encode_pass(password)
		end
	end

	def password_confirmation=(password)
		if !password.nil? && !password.empty?
			@password_confirmation = User.encode_pass(password)
		end
	end
	
	def self.encode_pass(password)
		Digest::SHA1.hexdigest(password).inspect[1,40]
	end
	
	def self.check_auth(login, password)
		User u = find_by_login(login)
		return (not u.nil?) && (u.password == User.encode_pass(password))
	end
	
end
