# encoding: utf-8
$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'simplecov'
SimpleCov.start do
  #add_filter "/json/"
end
SimpleCov.coverage_dir 'coverage'

require 'rspec'
require 'active_record'
require 'king_placeholder'

Dir[File.join(File.dirname(__FILE__),"support/**/*.rb")].each {|f| require f}
RSpec.configure do |config|
end