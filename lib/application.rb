require 'active_record'

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
	validates :url_before_type_cast, :format => { :with => /^https?:\/\/[a-z0-9._\/-]+\.[a-z]{2,3}/i, :on => :create }
		
	# Owner
	validates :user_id, :presence => true
	validates :user_id_before_type_cast, :format => { :with => /^[0-9]+$/, :on => :create }

	######################################
	# Class definition
	######################################
	
end
