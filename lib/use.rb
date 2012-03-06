require 'active_record'

class Use < ActiveRecord::Base
	
	belongs_to :user
	belongs_to :application
	
	######################################
	# Validators
	######################################
	
	# User
	validates :user_id, :presence => true
	validates :user_id, :format => { :with => /^[0-9]+$/, :on => :create }
	
	# Application
	validates :application_id, :presence => true
	validates :application_id, :format => { :with => /^[0-9]+$/, :on => :create }
	
	######################################
	# Class definition
	######################################
	
end
