require 'active_record'
require 'logger'

class Application < ActiveRecord::Base

	belongs_to :user
	has_many :uses
	
	######################################
	# Validators
	######################################
		
	# Name
	validates :name, :presence => true
	validates :name, :uniqueness => true
	validates :name_before_type_cast, :format => { :with => /^[a-z0-9_-]{3,}$/i, :on => :create }
	
	# URL
	validates :url, :presence => true
	validates :url, :uniqueness => true
	validates :url_before_type_cast, :format => { :with => /^https?:\/\/[a-z0-9._\/-:]+\.[a-z]{2,3}/i, :on => :create }
		
	# Owner
	validates :user_id, :presence => true
	validates :user_id_before_type_cast, :format => { :with => /^[0-9]+$/, :on => :create }
	
	# Public key
	validates :pubkey, :presence => true

	######################################
	# Class definition
	######################################
	def get_errs
		if errors.messages
			errs = errors.messages
			
			if errs[:name_before_type_cast] && errs[:name_before_type_cast].include?("is invalid")
				if !errs[:name]
					errs[:name] = []
				end
				errs[:name].push("must be an alphanumeric string with 3 characters at least")
				errs.delete(:name_before_type_cast)
			end
			
			if errs[:url_before_type_cast] && errs[:url_before_type_cast].include?("is invalid")
				if !errs[:url]
					errs[:url] = []
				end
				errs[:url].push("should match the indicated format")
				errs.delete(:url_before_type_cast)
			end
			
			return errs
		else
			return nil
		end
	end
	
	def delete_complete(logger)
		uses = Use.where(:application_id => id)
		
		uses.each do |u|
					settings.logger.info("Use deleted				(#{User.find_by_id(u.user_id).login}, #{self[:name]})")
					u.delete
					u.save
		end
		
		settings.logger.info("Application deleted			#{self[:name]}")
		delete
		save
		
		return true
	end
end
