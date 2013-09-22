require 'bundler/setup'
# use PryRescue::RACK if ENV["RACK_ENV"] == 'development'
Bundler.require(:default)
require './application'
run Website
