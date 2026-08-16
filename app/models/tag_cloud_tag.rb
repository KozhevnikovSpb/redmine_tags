# frozen_string_literal: true

# Optional restriction of a TagCloud to a subset of real RedmineUP tags
# (used when tag_cloud.tag_filter == true).
class TagCloudTag < ActiveRecord::Base
  self.table_name = 'tag_cloud_tags'

  belongs_to :tag_cloud
  # Absolute constant — avoid TagCloudTag::Redmineup::Tag under nested lookup
  belongs_to :tag, class_name: '::Redmineup::Tag', foreign_key: :tag_id, optional: true

  validates :tag_cloud_id, uniqueness: { scope: :tag_id }
  validates :tag_id, presence: true
end
