# frozen_string_literal: true

class TagCloudPreference < ActiveRecord::Base
  belongs_to :tag_cloud
  belongs_to :user

  validates :user_id, uniqueness: { scope: :tag_cloud_id }
  validates :visible, inclusion: { in: [true, false] }

  # position is optional (user-specific order of clouds); nil = use project order
  # show_untagged is personal: Reset deletes these rows, so the caption turns off.

  SYSTEM_HIDDEN_KEY = 'system_tag_cloud_hidden_project_ids'
  SYSTEM_SHOWN_KEY = 'system_tag_cloud_shown_project_ids'

  def show_untagged_enabled?
    return false unless self.class.column_names.include?('show_untagged')

    ActiveModel::Type::Boolean.new.cast(self[:show_untagged])
  rescue StandardError
    false
  end

  class << self
    def system_visible_for?(user, project)
      project_default = project_system_default(project)
      return project_default unless user&.logged? && project

      if system_hidden_project_ids(user).include?(project.id)
        false
      elsif system_shown_project_ids(user).include?(project.id)
        true
      else
        project_default
      end
    end

    def set_system_visible!(user, project, visible)
      return false unless user&.logged? && project

      hidden = system_hidden_project_ids(user)
      shown = system_shown_project_ids(user)
      if visible
        hidden.delete(project.id)
        shown |= [project.id]
      else
        shown.delete(project.id)
        hidden |= [project.id]
      end
      user.pref[SYSTEM_HIDDEN_KEY] = hidden
      user.pref[SYSTEM_SHOWN_KEY] = shown
      user.pref.save
    end

    def system_hidden_project_ids(user)
      pref_id_list(user, SYSTEM_HIDDEN_KEY)
    end

    def system_shown_project_ids(user)
      pref_id_list(user, SYSTEM_SHOWN_KEY)
    end

    def untagged_cloud_ids_for(user, cloud_ids = nil)
      return [] unless user&.logged?
      return [] unless table_exists?
      return [] unless column_names.include?('show_untagged')

      scope = where(user_id: user.id, show_untagged: true)
      scope = scope.where(tag_cloud_id: cloud_ids) if cloud_ids
      scope.pluck(:tag_cloud_id)
    rescue StandardError
      []
    end

    def clear_untagged_for_user!(user)
      return false unless user&.logged?
      return false unless table_exists?
      return false unless column_names.include?('show_untagged')

      scope = where(user_id: user.id, show_untagged: true)
      return false unless scope.exists?

      scope.update_all(show_untagged: false)
      true
    rescue StandardError => e
      Rails.logger.warn("[redmineup_tags] clear_untagged_for_user: #{e.class}: #{e.message}") if defined?(Rails)
      false
    end

    # Remove personal visibility/order/untagged rows for clouds on this project
    # and drop personal system-cloud overrides so the project default applies.
    def reset_for_user!(user, project)
      return false unless user&.logged? && project

      cloud_ids = (
        TagCloud.inherited_for(project).map(&:id) +
        TagCloud.for_project(project).map(&:id)
      ).uniq
      where(user_id: user.id, tag_cloud_id: cloud_ids).delete_all if cloud_ids.any?
      clear_system_override!(user, project)
      true
    end

    def clear_system_override!(user, project)
      return false unless user&.logged? && project

      hidden = system_hidden_project_ids(user)
      shown = system_shown_project_ids(user)
      hidden.delete(project.id)
      shown.delete(project.id)
      user.pref[SYSTEM_HIDDEN_KEY] = hidden
      user.pref[SYSTEM_SHOWN_KEY] = shown
      user.pref.save
    end

    private

    def project_system_default(project)
      if defined?(TagCloudProjectSetting)
        TagCloudProjectSetting.system_visible_by_default?(project)
      else
        true
      end
    end

    def pref_id_list(user, key)
      return [] unless user&.logged? && user.pref

      Array(user.pref[key]).map(&:to_i)
    rescue StandardError
      []
    end
  end
end
