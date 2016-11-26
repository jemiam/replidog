require "bundler/gem_tasks"

namespace :db do
  task :prepare do
    require File.expand_path("spec/dummy/config/application", File.dirname(__FILE__))
    Dummy::Application.load_tasks

    orig_env = ENV["RAILS_ENV"]
    begin
      Rails.env = "test_db_migration"
      Rake::Task["db:create"].invoke
      Rake::Task["db:schema:load"].invoke
    ensure
      ENV["RAILS_ENV"] = orig_env
    end

    file = File.expand_path('spec/dummy/config/database.yml', File.dirname(__FILE__))
    config = YAML.load_file(file)

    case config["test"]["adapter"]
    when "mysql2"
      3.times do |i|
        system("mysql -u root -e 'drop database replidog_test_slave#{i + 1}' > /dev/null 2> /dev/null")
        system("mysql -u root -e 'create database replidog_test_slave#{i + 1}'")
        system("mysqldump -u root replidog_test | mysql -u root replidog_test_slave#{i + 1}")
      end
      system("mysql -u root -e 'drop database replidog_test_user' > /dev/null 2> /dev/null")
      system("mysql -u root -e 'drop database replidog_test_user_slave' > /dev/null 2> /dev/null")
      system("mysql -u root -e 'create database replidog_test_user'")
      system("mysql -u root -e 'create database replidog_test_user_slave'")
      system("mysqldump -u root replidog_test | mysql -u root replidog_test_user")
      system("mysqldump -u root replidog_test | mysql -u root replidog_test_user_slave")
    when "sqlite"
      3.times do |i|
        FileUtils.copy("#{Rails.root}/db/test.sqlite3", "#{Rails.root}/db/test_slave#{i + 1}.sqlite3")
      end
      FileUtils.copy("#{Rails.root}/db/test.sqlite3", "#{Rails.root}/db/test_user.sqlite3")
      FileUtils.copy("#{Rails.root}/db/test.sqlite3", "#{Rails.root}/db/test_user_slave.sqlite3")
    end
  end
end
