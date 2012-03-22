$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'application'
require 'user'
require 'use'

require 'rspec'
require 'active_record'
require 'rack/test'

require_relative '../auth'

ENV['RACK_ENV'] = 'test'
