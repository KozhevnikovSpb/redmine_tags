module RedmineupTags
  module Patches
    module RoleIssueTagPermissionsPatch
      def permissions=(perms)
        super(RedmineupTags::IssueTagPermissions.sanitize_permission_list(perms))
      end
    end
  end
end

unless defined?(Role) && Role.ancestors.include?(RedmineupTags::Patches::RoleIssueTagPermissionsPatch)
  Role.prepend(RedmineupTags::Patches::RoleIssueTagPermissionsPatch) if defined?(Role)
end
