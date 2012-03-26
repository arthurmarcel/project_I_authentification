require 'digest/sha1'
require 'active_record'
require 'logger'

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


	######################################
	# Class definition
	######################################

	# Encrypt passwords
	def password=(password)
		if password =~ /^[a-z0-9]{4,20}$/i
			@password = User.encode_pass(password)
			self[:password] = User.encode_pass(password)
		end
	end
	
	def self.encode_pass(password)
		Digest::SHA1.hexdigest(password).inspect[1,40]
	end
	
	def self.check_auth(login, password)
		User u = find_by_login(login)
		return (not u.nil?) && (u.password == User.encode_pass(password))
	end
	
	def delete_complete(logger)
		uses = Use.where(:user_id => id)
		
		uses.each do |u|
					u.delete
					u.save
					logger.info("Use deleted					(#{self[:login]}, #{(Application.find_by_id(u.application_id)).name})")
		end
		
		apps = Application.where(:user_id => id)
		apps.each do |a|
					logger.info("Application deleted			#{a.name}")
					a.delete
					a.save	
		end
		
		logger.info("User deleted					#{self[:login]}")
		delete
		save
		
		return true
	end
	
	
	def self.authenticate(login, pass)
		if User.find_by_login(login)
			if User.find_by_login(login).password == User.encode_pass(pass)
				return {:ok => true}
			else
				return {:ok => false, :errs => {:password => "is wrong"}}
			end
		else
			return {:ok => false, :errs => {:login => "not found"}}
		end
	end
	


	def find_apps_own
		if admin
			return Application.find(:all)
		else
			return Application.where(:user_id => id)
		end
	end
	
	
	
	def find_apps_use
		uses = Use.where(:user_id => id)
		apps_linked = []
		uses.each do |use|
			apps_linked.push(Application.find_by_id(use.application_id))
		end
		return apps_linked
	end



	def get_errs
		if errors.messages
			errs = errors.messages
			
			if errs[:password] && errs[:password].include?("is invalid")
				errs[:password].delete("is invalid")
				errs[:password].push("must be an alphanumeric string between 4 and 20 characters")
			end
			
			if errs[:login] && errs[:login].include?("is invalid")
				errs[:login].delete("is invalid")
				errs[:login].push("must be an alphanumeric string between 4 and 20 characters")				
			end
			
			return errs
		else
			return nil
		end
	end
end
