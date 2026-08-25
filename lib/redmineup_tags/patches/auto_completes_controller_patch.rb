# This file is a part of Redmine Tags (redmine_tags) plugin,
# customer relationship management plugin for Redmine
#
# Copyright (C) 2011-2026 RedmineUP
# http://www.redmineup.com/
#
# redmine_tags is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_tags is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_tags.  If not, see <http://www.gnu.org/licenses/>.

require_dependency 'auto_completes_controller'

module RedmineupTags
  module Patches
    module AutoCompletesControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
        end
      end

      module InstanceMethods
        DEFAULT_AUTOCOMPLETE_LIMIT = 30

        def redmine_tags
          scope = autocomplete_tags_scope
          page = [params[:page].to_i, 1].max
          limit = autocomplete_page_size
          offset = (page - 1) * limit
          tags = scope.offset(offset).limit(limit + 1).to_a
          more = tags.size > limit
          tags = tags.first(limit)
          payload = format_redmine_tags_json(tags)

          if params[:page].present?
            render json: { results: payload, pagination: { more: more } }
          else
            render json: payload
          end
        end

        private

        def autocomplete_page_size
          limit = params[:limit].present? ? params[:limit].to_i : DEFAULT_AUTOCOMPLETE_LIMIT
          limit = DEFAULT_AUTOCOMPLETE_LIMIT if limit <= 0
          limit
        end

        # Full tags table (not Issue.visible / not grouped by issue counts).
        def autocomplete_tags_scope
          tags_table = Redmineup::Tag.table_name
          taggings_table = Redmineup::Tagging.table_name
          q = (params[:q] || params[:term]).to_s.strip
          suggestion_order = RedmineupTags.settings['tags_suggestion_order'] || 'name'

          scope = Redmineup::Tag.all
          if q.present?
            scope = scope.where("LOWER(#{tags_table}.name) LIKE LOWER(?)",
                                "%#{Redmineup::Tag.sanitize_sql_like(q)}%")
          end

          case suggestion_order
          when 'most_used'
            scope.joins("LEFT JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id AND #{taggings_table}.taggable_type = #{Redmineup::Tag.connection.quote('Issue')}")
                 .group("#{tags_table}.id")
                 .order(Arel.sql("COUNT(#{taggings_table}.id) DESC"), Arel.sql("#{tags_table}.name ASC"))
          when 'last_created'
            if Redmineup::Tag.column_names.include?('created_at')
              scope.order(Arel.sql("#{tags_table}.created_at DESC"), Arel.sql("#{tags_table}.name ASC"))
            else
              scope.order(Arel.sql("#{tags_table}.name ASC"))
            end
          else
            scope.order(Arel.sql("#{tags_table}.name ASC"))
          end
        end

        def format_redmine_tags_json(redmine_tags)
          redmine_tags.map do |redmine_tag|
            {
              id: redmine_tag.name,
              text: redmine_tag.name
            }
          end
        end
      end
    end
  end
end

unless AutoCompletesController.included_modules.include?(RedmineupTags::Patches::AutoCompletesControllerPatch)
  AutoCompletesController.send(:include, RedmineupTags::Patches::AutoCompletesControllerPatch)
end
