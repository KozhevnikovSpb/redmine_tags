# frozen_string_literal: true

class TagCloudPreference < ActiveRecord::Base
  belongs_to :tag_cloud
  belongs_to :user

  validates :user_id, uniqueness: { scope: :tag_cloud_id }
  validates :visible, inclusion: { in: [true, false] }

  # position is optional (user-specific order of clouds); nil = use project order
  # show_untagged is personal: Reset deletes these rows, so the caption turns off.

  SYSTEM_HIDDEN_KEY = 'system_tag_cloud_hidden_project_ids'

  def show_untagged_enabled?
    return false unless self.class.column_names.include?('show_untagged')

    ActiveModel::Type::Boolean.new.cast(self[:show_untagged])
  rescue StandardError
    false
  end

  class << self
    def system_visible_for?(user, project)
      return true unless user&.logged? && project

      !system_hidden_project_ids(user).include?(project.id)
    end

    def set_system_visible!(user, project, visible)
      return false unless user&.logged? && project

      ids = system_hidden_project_ids(user)
      if visible
        ids.delete(project.id)
      else
        ids |= [project.id]
      end
      user.pref[SYSTEM_HIDDEN_KEY] = ids
      user.pref.save
    end

    def system_hidden_project_ids(user)
      return [] unless user&.logged? && user.pref

      Array(user.pref[SYSTEM_HIDDEN_KEY]).map(&:to_i)
    rescue StandardError
      []
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
    # and show the system Tags cloud again.
    def reset_for_user!(user, project)
      return false unless user&.logged? && project

      cloud_ids = (
        TagCloud.inherited_for(project).map(&:id) +
        TagCloud.for_project(project).map(&:id)
      ).uniq
      where(user_id: user.id, tag_cloud_id: cloud_ids).delete_all if cloud_ids.any?
      set_system_visible!(user, project, true)
      true
    end
  end
end
