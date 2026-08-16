class Organization < ApplicationRecord
  has_many :facilities
  has_many :users
  has_many :patients

  validates :name, presence: true, uniqueness: true
end
