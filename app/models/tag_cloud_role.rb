# frozen_string_literal: true

# Roles that may see a TagCloud when visibility == 'roles'.
class TagCloudRole < ActiveRecord::Base
  self.table_name = 'tag_cloud_roles'

  belongs_to :tag_cloud
  belongs_to :role

  validates :tag_cloud_id, uniqueness: { scope: :role_id }
end
