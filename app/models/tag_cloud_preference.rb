# frozen_string_literal: true

class TagCloudPreference < ActiveRecord::Base
  belongs_to :tag_cloud
  belongs_to :user

  validates :user_id, uniqueness: { scope: :tag_cloud_id }
  validates :visible, inclusion: { in: [true, false] }

  # position is optional (user-specific order of clouds); nil = use project order
end
