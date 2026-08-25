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
        base.prepend(InstanceMethods)
      end

      module InstanceMethods
        def redmine_tags
          tags = autocomplete_tags_scope.to_a
          payload = tags.map { |tag| { id: tag.name, text: tag.name } }

          if params[:page].present?
            render json: { results: payload, pagination: { more: false } }
          else
            render json: payload
          end
        end

        private

        def autocomplete_tags_scope
          tags_table = Redmineup::Tag.table_name
          q = (params[:q] || params[:term]).to_s.strip
          suggestion_order = RedmineupTags.settings['tags_suggestion_order'] || 'name'

          scope = Redmineup::Tag.unscoped
          if q.present?
            scope = scope.where("LOWER(#{tags_table}.name) LIKE LOWER(?)",
                                "%#{Redmineup::Tag.sanitize_sql_like(q)}%")
          end

          case suggestion_order
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
      end
    end
  end
end

unless AutoCompletesController.included_modules.include?(RedmineupTags::Patches::AutoCompletesControllerPatch)
  AutoCompletesController.send(:include, RedmineupTags::Patches::AutoCompletesControllerPatch)
end
