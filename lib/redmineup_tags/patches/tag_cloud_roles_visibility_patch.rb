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

        return true if user.admin?
        return true if self.class.can_manage?(user, project)
        return false unless visibility_allows?(user, project)

        visible_by_default?
      end

      private

      def visibility_allows?(user, project)
        case visibility.to_s
        when 'all'
          true
        when 'roles'
          user&.admin? || authored_by?(user) || roles_match?(user, project)
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

        have = project_role_ids_for(user, project)
        (wanted & have).any?
      end

      def project_role_ids_for(user, project)
        ids = []
        if user.respond_to?(:roles_for_project)
          ids.concat(Array(user.roles_for_project(project)).map { |role| role.id.to_i })
        end

        membership =
          if user.respond_to?(:membership)
            user.membership(project)
          elsif project.respond_to?(:memberships)
            project.memberships.find_by(user_id: user.id)
          end

        if membership
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
        Rails.logger.warn("[redmineup_tags] project_role_ids_for: #{e.class}: #{e.message}") if defined?(Rails) && Rails.logger
        []
      end
    end
  end
end
