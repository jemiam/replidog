class Recipe < ActiveRecord::Base
  scope :recent, -> {
    where("created_at > ?", Time.now - 1.day)
  }
  has_many :ingredients
end
