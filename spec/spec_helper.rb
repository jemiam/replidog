$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "replidog"
require "database_rewinder"
require "pry"

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../dummy/config/environment", __FILE__)
require "rspec/rails"

RSpec.configure do |config|
  copy_master_to_slave = proc do |adapter|
    case adapter
    when :mysql2
      3.times do |i|
        system("mysql -u root -e 'drop database dummy_test_slave#{i + 1}' > /dev/null 2> /dev/null")
        system("mysql -u root -e 'create database dummy_test_slave#{i + 1}'")
        system("mysqldump -u root dummy_test | mysql -u root dummy_test_slave#{i + 1}")
      end
      system("mysql -u root -e 'drop database dummy_test_user' > /dev/null 2> /dev/null")
      system("mysql -u root -e 'drop database dummy_test_user_slave' > /dev/null 2> /dev/null")
      system("mysql -u root -e 'create database dummy_test_user'")
      system("mysql -u root -e 'create database dummy_test_user_slave'")
      system("mysqldump -u root dummy_test | mysql -u root dummy_test_user")
      system("mysqldump -u root dummy_test | mysql -u root dummy_test_user_slave")
    when :sqlite3
      3.times do |i|
        FileUtils.copy("#{Rails.root}/db/test.sqlite3", "#{Rails.root}/db/test_slave#{i + 1}.sqlite3")
      end
      FileUtils.copy("#{Rails.root}/db/test.sqlite3", "#{Rails.root}/db/test_user.sqlite3")
      FileUtils.copy("#{Rails.root}/db/test.sqlite3", "#{Rails.root}/db/test_user_slave.sqlite3")
    end
  end

  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run :focus

  config.before(:suite) do
    DatabaseRewinder["test"]
    DatabaseRewinder["test_slave1"]
    DatabaseRewinder["test_slave2"]
    DatabaseRewinder["test_slave3"]
    DatabaseRewinder["test_user"]
    DatabaseRewinder["test_user_slave"]
    DatabaseRewinder.clean_all
    copy_master_to_slave.call(:mysql2)
  end

  config.after(:each) do
    DatabaseRewinder.clean
  end
end
