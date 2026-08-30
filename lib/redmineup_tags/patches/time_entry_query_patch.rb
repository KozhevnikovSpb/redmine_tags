module RedmineupTags
  module Patches
    module TimeEntryQueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :statement_without_redmine_tags, :statement
          alias_method :statement, :statement_with_redmine_tags
          alias_method :available_filters_without_redmine_tags, :available_filters
          alias_method :available_filters, :available_filters_with_redmine_tags
          add_available_column QueryTagsColumn.new(:tags_relations, caption: :tags)
        end
      end

      module InstanceMethods
        def statement_with_redmine_tags
          filter = filters.delete('issue_tags')
          clauses = statement_without_redmine_tags || ''
          return clauses unless filter

          filters['issue_tags'] = filter
          issues = Issue.all
          operator = operator_for('issue_tags')
          issues =
            case operator
            when '=', '!'
              issues.tagged_with(values_for('issue_tags').clone, match_all: true)
            when '!*'
              issues.joins(:tags).distinct
            else
              issues.joins(:tags).distinct
            end

          compare = operator.include?('!') ? 'NOT IN' : 'IN'
          clauses << ' AND ' unless clauses.empty?
          clauses << "(#{TimeEntry.table_name}.issue_id #{compare} (#{tagged_issue_ids_sql(issues)}))"
          clauses
        ensure
          filters['issue_tags'] = filter if filter
        end

        def available_filters_with_redmine_tags
          available_filters_without_redmine_tags
          selected_tags = Array(filters.dig('issue_tags', :values))
                               .reject(&:blank?)
                               .uniq
                               .map { |name| [name, name] }
          add_available_filter(
            'issue_tags',
            type: :list_optional,
            name: l(:tags),
            values: selected_tags
          )
        end

        private

        def tagged_issue_ids_sql(issues)
          if issues.respond_to?(:reselect) && issues.respond_to?(:to_sql)
            return issues.reselect("#{Issue.table_name}.id").to_sql
          end

          ids = Array(issues).filter_map do |issue|
            issue.respond_to?(:id) ? issue.id : issue
          end.map(&:to_i).uniq

          (ids.presence || [0]).join(',')
        end
      end
    end
  end
end

if (ActiveRecord::Base.connection.tables.include?('queries') rescue false) &&
   TimeEntryQuery.included_modules.exclude?(RedmineupTags::Patches::TimeEntryQueryPatch)
  TimeEntryQuery.send(:include, RedmineupTags::Patches::TimeEntryQueryPatch)
end
