# frozen_string_literal: true

class TagCloudProjectSetting < ActiveRecord::Base
  belongs_to :project

  validates :project_id, uniqueness: true
  validates :system_visible_by_default, inclusion: { in: [true, false] }

  class << self
    def system_visible_by_default?(project)
      return true unless project && table_exists?

      rec = find_by(project_id: project.id)
      rec.nil? ? true : rec.system_visible_by_default?
    rescue StandardError
      true
    end

    def set_system_visible_by_default!(project, visible)
      return false unless project && table_exists?

      rec = find_or_initialize_by(project_id: project.id)
      rec.system_visible_by_default = ActiveModel::Type::Boolean.new.cast(visible)
      rec.save!
      rec.system_visible_by_default?
    rescue StandardError => e
      Rails.logger.warn("[redmineup_tags] set_system_visible_by_default: #{e.class}: #{e.message}") if defined?(Rails)
      false
    end
  end
end
