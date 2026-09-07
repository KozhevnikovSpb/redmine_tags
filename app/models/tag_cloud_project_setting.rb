# frozen_string_literal: true

class TagCloudProjectSetting < ActiveRecord::Base
  belongs_to :project

  validates :project_id, uniqueness: true
  validates :system_visible_by_default, inclusion: { in: [true, false] }

  class << self
    def record_for(project)
      return nil unless project && table_exists?

      find_or_initialize_by(project_id: project.id)
    rescue StandardError
      nil
    end

    def system_visible_by_default?(project)
      return true unless project && table_exists?
      return false if hidden_by_ancestor?(project)

      local_visible_by_default?(project)
    rescue StandardError
      true
    end

    def local_visible_by_default?(project)
      return true unless project && table_exists?

      rec = find_by(project_id: project.id)
      rec.nil? ? true : rec.system_visible_by_default?
    rescue StandardError
      true
    end

    def local_include_subprojects?(project)
      return false unless project && table_exists? && include_subprojects_column?

      rec = find_by(project_id: project.id)
      rec.present? && rec.include_subprojects?
    rescue StandardError
      false
    end

    def locked_by_ancestor?(project)
      hidden_by_ancestor?(project)
    end

    def hidden_by_ancestor?(project)
      return false unless project && table_exists? && include_subprojects_column?
      return false unless project.respond_to?(:ancestors)

      Array(project.ancestors).any? do |parent|
        rec = find_by(project_id: parent.id)
        rec && !rec.system_visible_by_default? && rec.include_subprojects?
      end
    rescue StandardError
      false
    end

    def set_system_visible_by_default!(project, visible)
      update_system!(project, visible: visible, include_subprojects: local_include_subprojects?(project))
    end

    def update_system!(project, visible:, include_subprojects: false)
      return false unless project && table_exists?

      rec = find_or_initialize_by(project_id: project.id)
      visible = ActiveModel::Type::Boolean.new.cast(visible)
      include_subprojects = ActiveModel::Type::Boolean.new.cast(include_subprojects)
      include_subprojects = false if visible
      rec.system_visible_by_default = visible
      rec.include_subprojects = include_subprojects if include_subprojects_column?
      rec.save!
      rec.system_visible_by_default?
    rescue StandardError => e
      Rails.logger.warn("[redmineup_tags] update_system: #{e.class}: #{e.message}") if defined?(Rails)
      false
    end

    def include_subprojects_column?
      table_exists? && column_names.include?('include_subprojects')
    rescue StandardError
      false
    end
  end
end
