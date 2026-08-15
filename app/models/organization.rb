class Organization < ApplicationRecord
  has_many :facilities
  has_many :users

  validates :name, presence: true, uniqueness: true
end
