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
          add_available_filter(
            'issue_tags',
            type: :list_optional,
            name: l(:tags),
            remote: false,
            values: issue_tag_filter_values
          )
        end

        private

        def issue_tag_filter_values
          names = issue_tag_names_for_filter
          selected = Array(filters.dig('issue_tags', :values)).reject(&:blank?)
          (names | selected).map { |name| [name, name] }
        end

        def issue_tag_names_for_filter
          tags_table = Redmineup::Tag.table_name
          taggings_table = Redmineup::Tagging.table_name
          issues_table = Issue.table_name

          scope = Redmineup::Tag.unscoped
                                .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
                                .where("#{taggings_table}.taggable_type = ?", 'Issue')

          if project
            scope = scope.joins(
                      "INNER JOIN #{issues_table} ON #{issues_table}.id = #{taggings_table}.taggable_id"
                    )
                    .where(issues_table => { project_id: project.id })
          end

          scope.distinct.order(Arel.sql("#{tags_table}.name ASC")).pluck(Arel.sql("#{tags_table}.name"))
        rescue StandardError => e
          Rails.logger.warn("[redmineup_tags] Time entry tag filter values: #{e.class}: #{e.message}")
          []
        end

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
