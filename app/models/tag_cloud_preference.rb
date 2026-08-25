# frozen_string_literal: true

class TagCloudPreference < ActiveRecord::Base
  belongs_to :tag_cloud
  belongs_to :user

  validates :user_id, uniqueness: { scope: :tag_cloud_id }
  validates :visible, inclusion: { in: [true, false] }

  # position is optional (user-specific order of clouds); nil = use project order

  SYSTEM_HIDDEN_KEY = 'system_tag_cloud_hidden_project_ids'

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

    # Remove personal visibility/order rows for clouds on this project
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
