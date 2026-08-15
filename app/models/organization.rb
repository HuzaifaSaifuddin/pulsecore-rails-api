class Organization < ApplicationRecord
  has_many :facilities

  validates :name, presence: true, uniqueness: true
end
