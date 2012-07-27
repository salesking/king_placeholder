# encoding: utf-8
$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
ENV["RAILS_ENV"] ||= 'test'

require 'simplecov'
SimpleCov.start do
  add_filter "/json/"
end
SimpleCov.coverage_dir 'coverage'

require 'rubygems'
require 'rspec'
require 'active_record'
require 'king_placeholder'



RSpec.configure do |config|
end