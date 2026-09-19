module RedmineupTags
  module IssueTagPermissions
    module_function

    def can_edit_issue_tags?(user, project)
      user.present? && user.allowed_to?(:edit_issue_tags, project)
    end

    def can_create_issue_tags?(user, project)
      user.present? && user.allowed_to?(:create_issue_tags, project)
    end

    # Roles that had the shared RedmineUP names keep issue-tag access after the split.
    # Q&A continues to own :create_tags / :edit_tags.
    def migrate_legacy_role_permissions!
      return unless defined?(Role)
      return unless Role.table_exists?

      Role.find_each do |role|
        perms = Array(role.permissions).map(&:to_sym)
        to_add = []
        to_add << :edit_issue_tags if perms.include?(:edit_tags) && !perms.include?(:edit_issue_tags)
        to_add << :create_issue_tags if perms.include?(:create_tags) && !perms.include?(:create_issue_tags)
        role.add_permission!(*to_add) if to_add.any?
      end
    rescue StandardError => e
      if defined?(Rails) && Rails.logger
        Rails.logger.warn("[redmineup_tags] migrate issue tag permissions: #{e.class}: #{e.message}")
      end
    end
  end

  def self.can_edit_issue_tags?(user, project)
    IssueTagPermissions.can_edit_issue_tags?(user, project)
  end

  def self.can_create_issue_tags?(user, project)
    IssueTagPermissions.can_create_issue_tags?(user, project)
  end
end
