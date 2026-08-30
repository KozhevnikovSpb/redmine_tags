module RedmineupTags
  module Patches
    module IssueQueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :statement_without_redmine_tags, :statement
          alias_method :statement, :statement_with_redmine_tags
          alias_method :available_filters_without_redmine_tags, :available_filters
          alias_method :available_filters, :available_filters_with_redmine_tags
          alias_method :available_filters_as_json_without_redmine_tags, :available_filters_as_json
          alias_method :available_filters_as_json, :available_filters_as_json_with_redmine_tags
          alias_method :build_from_params_without_redmine_tags, :build_from_params
          alias_method :build_from_params, :build_from_params_with_redmine_tags
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
          clauses << "(#{Issue.table_name}.id #{compare} (#{tagged_issue_ids_sql(issues)}))"
          clauses
        ensure
          filters['issue_tags'] = filter if filter
        end

        def available_filters_with_redmine_tags
          available = available_filters_without_redmine_tags
          add_available_filter(
            'issue_tags',
            type: :list_optional,
            name: l(:tags),
            remote: false,
            values: -> { issue_tag_filter_values }
          )
          available
        rescue StandardError => e
          Rails.logger.warn("[redmineup_tags] Tag filter error: #{e.class}: #{e.message}")
          available || @available_filters || {}
        end

        def available_filters_as_json_with_redmine_tags
          json = available_filters_as_json_without_redmine_tags || {}
          json = json.stringify_keys
          entry = (json['issue_tags'] || {}).stringify_keys
          entry['type'] = 'list_optional'
          entry['name'] ||= l(:tags)
          entry['remote'] = false
          entry['values'] = issue_tag_filter_values
          json['issue_tags'] = entry
          json
        rescue StandardError => e
          Rails.logger.warn("[redmineup_tags] Tag filter json: #{e.class}: #{e.message}")
          available_filters_as_json_without_redmine_tags
        end

        def build_from_params_with_redmine_tags(params, defaults = {})
          build_from_params_without_redmine_tags(params, defaults)
          tag = Redmineup::Tag.find_by(id: params[:tag_id]) if params[:tag_id].present?
          add_filter('issue_tags', '=', [tag.name]) if tag
          self
        end

        private

        def issue_tag_filter_values
          names = issue_tag_names_for_filter
          selected = Array(filters.dig('issue_tags', :values)).reject(&:blank?)
          (names | selected).map { |name| [name, name] }
        end

        def issue_tag_names_for_filter
          opts = { user: User.current }
          if project
            projects = [project]
            if respond_to?(:with_subprojects?) && with_subprojects?
              projects.concat(Array(project.descendants.to_a))
            end
            opts[:projects] = projects
          end
          Issue.all_tags(opts).map { |tag| tag.name.to_s }.reject(&:blank?)
        rescue StandardError => e
          Rails.logger.warn("[redmineup_tags] Tag filter values via all_tags: #{e.class}: #{e.message}")
          issue_tag_names_fallback
        end

        def issue_tag_names_fallback
          tags_table = Redmineup::Tag.table_name
          taggings_table = Redmineup::Tagging.table_name
          Redmineup::Tag.unscoped
                        .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
                        .where("#{taggings_table}.taggable_type = ?", 'Issue')
                        .distinct
                        .order(Arel.sql("#{tags_table}.name ASC"))
                        .pluck(Arel.sql("#{tags_table}.name"))
        rescue StandardError => e
          Rails.logger.warn("[redmineup_tags] Tag filter fallback: #{e.class}: #{e.message}")
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
   IssueQuery.included_modules.exclude?(RedmineupTags::Patches::IssueQueryPatch)
  IssueQuery.send(:include, RedmineupTags::Patches::IssueQueryPatch)
end
