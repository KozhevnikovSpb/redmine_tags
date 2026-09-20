# frozen_string_literal: true

module RedmineupTags
  module Patches
    module TagCloudRolesVisibilityPatch
      def visibility_allowed_for?(user, project)
        visibility_allows?(user, project)
      end

      def listed_in_settings_for?(user, project: nil, context: :project)
        return false if user.nil?
        return user.admin? if context.to_sym == :admin
        return false unless project
        return false unless self.class.can_view_settings_list?(user, project)

        return true if authored_by?(user)
        return false if author_only?
        return false unless visibility_allows?(user, project)

        return true if self.class.can_manage?(user, project)
        visible_by_default?
      end

      def manageable_by?(user, project: nil, context: :project)
        return false if user.nil?
        return user.admin? if context.to_sym == :admin

        if author_only?
          return false unless authored_by?(user)
          return false unless project
          return true if user.admin?
          return user.allowed_to?(:manage_tag_clouds, project)
        end

        return false unless project
        if visibility.to_s == 'roles'
          return false unless visibility_allows?(user, project)
        end

        return true if user.admin?
        user.allowed_to?(:manage_tag_clouds, project)
      end

      private

      def visibility_allows?(user, project)
        case visibility.to_s
        when 'all'
          true
        when 'roles'
          authored_by?(user) || roles_match?(user, project)
        when 'owner'
          authored_by?(user)
        else
          false
        end
      end

      def roles_match?(user, project)
        return false unless user&.logged? && project

        wanted = Array(assigned_role_ids).map(&:to_i).reject(&:zero?)
        return false if wanted.empty?

        have = membership_role_ids_for(user, project)
        (wanted & have).any?
      end

      # Real project membership only. Do not call User#roles_for_project —
      # full admins get every givable role there even with no membership.
      def membership_role_ids_for(user, project)
        ids = []

        memberships = []
        if user.respond_to?(:membership)
          memberships << user.membership(project)
        end
        if project.respond_to?(:memberships)
          memberships.concat(Array(project.memberships.where(user_id: user.id)))
          if user.respond_to?(:groups)
            group_ids = Array(user.groups).map(&:id)
            if group_ids.any?
              memberships.concat(Array(project.memberships.where(user_id: group_ids)))
            end
          end
        end

        memberships.compact.uniq.each do |membership|
          if membership.respond_to?(:roles)
            ids.concat(Array(membership.roles).map { |role| role.id.to_i })
          end
          if membership.respond_to?(:member_roles)
            ids.concat(Array(membership.member_roles).map { |mr| mr.role_id.to_i })
          end
          if membership.respond_to?(:role_ids)
            ids.concat(Array(membership.role_ids).map(&:to_i))
          end
        end

        ids.reject(&:zero?).uniq
      rescue StandardError => e
        Rails.logger.warn("[redmineup_tags] membership_role_ids_for: #{e.class}: #{e.message}") if defined?(Rails) && Rails.logger
        []
      end
    end
  end
end
