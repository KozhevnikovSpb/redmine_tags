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
        MAX_AUTOCOMPLETE_LIMIT = 100
        SORTING_FIELDS = { 'name' => 'name',
                           'last_created' => 'created_at',
                           'most_used' => 'count' }

        def redmine_tags
          suggestion_order = RedmineupTags.settings['tags_suggestion_order'] || 'name'
          options = {
            name_like: (params[:q] || params[:term]).to_s.strip,
            sort_by: SORTING_FIELDS[suggestion_order],
            order: (suggestion_order == 'name' ? 'ASC' : 'DESC')
          }
          scope = Issue.all_tags(options)
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
          [limit, MAX_AUTOCOMPLETE_LIMIT].min
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
