# frozen_string_literal: true

# Join table: TagCloud <-> Project with per-project ordering.
# No timestamps by design (see SchemaRepair).
class TagCloudProject < ActiveRecord::Base
  self.table_name = 'tag_cloud_projects'

  belongs_to :tag_cloud, inverse_of: :tag_cloud_projects
  belongs_to :project

  validates :tag_cloud_id, uniqueness: { scope: :project_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(:position, :id) }
end
