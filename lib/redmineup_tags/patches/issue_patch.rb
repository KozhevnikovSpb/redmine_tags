require_dependency 'issue'

module RedmineupTags
  module Patches
    module IssuePatch
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          include InstanceMethods
          up_acts_as_taggable

          alias_method :safe_attributes_without_safe_tags=, :safe_attributes=
          alias_method :safe_attributes=, :safe_attributes_with_safe_tags=

          class << self
            alias_method :available_tags_without_redmine_tags, :available_tags
            alias_method :available_tags, :available_tags_with_redmine_tags
          end

          alias_method :copy_from_without_redmine_tags, :copy_from
          alias_method :copy_from, :copy_from_with_redmine_tags
        end
      end

      class TagsRelations < IssueRelation::Relations
        def to_s(*)
          map(&:name).join(', ')
        end
      end

      module ClassMethods
        def available_tags_with_redmine_tags(options = {})
          scope = available_tags_without_redmine_tags(options)
          return scope unless options[:open_only]

          scope.joins("JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{table_name}.status_id")
               .where("#{IssueStatus.table_name}.is_closed = ?", false)
        end

        def all_tags(options = {})
          tags_table = Redmineup::Tag.table_name
          taggings_table = Redmineup::Tagging.table_name
          issues_table = Issue.table_name

          issues = if options[:all_issues]
                     Issue.unscoped.select(:id)
                   else
                     Issue.visible(options[:user] || User.current)
                   end
          projects = Array(options[:projects] || options[:project]).compact
          issues = issues.where(project_id: projects.map { |project| project.respond_to?(:id) ? project.id : project }) if projects.any?
          issues = issues.joins(:status).where(issue_statuses: { is_closed: false }) if options[:open_only]

          scope = Redmineup::Tag
                  .joins("JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
                  .where("#{taggings_table}.taggable_type = ?", Issue.name)
                  .where("#{taggings_table}.taggable_id IN (#{issues.select(:id).to_sql})")

          if options[:name_like].present?
            scope = scope.where("LOWER(#{tags_table}.name) LIKE LOWER(?)", "%#{sanitize_sql_like(options[:name_like])}%")
          end

          columns = [
            "#{tags_table}.id",
            "#{tags_table}.name",
            "#{tags_table}.color",
            "COUNT(DISTINCT #{taggings_table}.taggable_id) AS count"
          ]
          columns << "MIN(#{taggings_table}.created_at) AS created_at" if options[:sort_by] == 'created_at'

          allowed_sort = {
            'name' => "#{tags_table}.name",
            'count' => 'count',
            'created_at' => 'created_at'
          }
          sort_column = allowed_sort.fetch(options[:sort_by].to_s, "#{tags_table}.name")
          sort_order = options[:order].to_s.upcase == 'DESC' ? 'DESC' : 'ASC'

          scope.select(columns.join(', '))
               .group("#{tags_table}.id, #{tags_table}.name, #{tags_table}.color")
               .having('COUNT(*) > 0')
               .order(Arel.sql("#{sort_column} #{sort_order}"))
        end

        def project_tags(project)
          all_tags(project: project)
        end

        def allowed_tags?(tags)
          requested = Array(tags).reject(&:blank?).uniq
          return true if requested.empty?

          Redmineup::Tag.where(name: requested).distinct.count == requested.size
        end

        def by_tags(project, with_subprojects = false)
          count_and_group_by_with_redmine_tags(project: project, association: :tags, with_subprojects: with_subprojects)
        end

        def count_and_group_by_with_redmine_tags(options)
          return count_and_group_by_without_redmine_tags(options) unless options[:association] == :tags

          association = reflect_on_association(options[:association])
          select_field = association.foreign_key

          Issue.visible(User.current, project: options[:project], with_subprojects: options[:with_subprojects])
               .joins(:status, association.name)
               .group(:status_id, :is_closed, select_field)
               .count
               .map do |columns, total|
            status_id, is_closed, field_value = columns
            {
              'status_id' => status_id.to_s,
              'closed' => %w[t true 1].include?(is_closed.to_s),
              select_field => field_value.to_s,
              'total' => total.to_s
            }
          end
        end
      end

      module InstanceMethods
        def safe_attributes_with_safe_tags=(attrs, user = User.current)
          self.send(:safe_attributes_without_safe_tags=, attrs, user)
          return unless attrs && (attrs[:tag_list] || attrs[:add_tag_list] || attrs[:remove_tag_list])
          return unless user.allowed_to?(:edit_tags, project)

          tags = attrs[:tag_list] || (Array(tag_list) + Array(attrs[:add_tag_list]) - Array(attrs[:remove_tag_list]))
          tags = tags.reject(&:blank?).uniq
          self.tag_list = tags if user.allowed_to?(:create_tags, project) || Issue.allowed_tags?(tags)
        end

        def tags_relations
          TagsRelations.new(self, tags.to_a)
        end

        def copy_from_with_redmine_tags(arg, options = {})
          original_issue = arg.is_a?(Issue) ? arg : Issue.visible.find(arg)
          copied_issue = copy_from_without_redmine_tags(original_issue, options)
          copied_issue.tags = original_issue.tags
          copied_issue
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineupTags::Patches::IssuePatch)
  Issue.send(:include, RedmineupTags::Patches::IssuePatch)
end
