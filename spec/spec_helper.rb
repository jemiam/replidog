$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "replidog"
require "database_rewinder"
require "pry"

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../dummy/config/environment", __FILE__)
require "rspec/rails"

RSpec.configure do |config|

  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.before(:suite) do
    DatabaseRewinder["test"]
    DatabaseRewinder["test_slave1"]
    DatabaseRewinder["test_slave2"]
    DatabaseRewinder["test_slave3"]
    DatabaseRewinder["test_user"]
    DatabaseRewinder["test_user_slave"]
    DatabaseRewinder.clean_all
  end

  config.after(:each) do
    DatabaseRewinder.clean
  end
end
