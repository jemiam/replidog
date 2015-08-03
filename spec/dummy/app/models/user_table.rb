class UserTable < ActiveRecord::Base
  self.abstract_class = true

  establish_connection :test_user
end
