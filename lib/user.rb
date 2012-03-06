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
	def password
		@password
	end
	
	def password_confirmation
		@password_confirmation
	end
	
	# Encrypt passwords
	def password=(password)
		unless password.nil?
			@password = Digest::SHA1.hexdigest(password)
		end
	end

	def password_confirmation=(password)
		unless password.nil?
			@password_confirmation = Digest::SHA1.hexdigest(password)
		end
	end

end
