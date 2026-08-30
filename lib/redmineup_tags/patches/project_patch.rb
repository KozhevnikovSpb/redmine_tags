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

module RedmineupTags
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          has_many :tag_cloud_projects, dependent: :destroy
          has_many :tag_clouds, through: :tag_cloud_projects
          after_create :enable_redmineup_tags_module

          # Default system cloud is virtual (not stored in DB).
          def enable_redmineup_tags_module
            return if module_enabled?(:redmineup_tags)

            enabled_modules.create(name: 'redmineup_tags')
          rescue StandardError => e
            Rails.logger.warn("[redmineup_tags] enable module project=#{id}: #{e.class}: #{e.message}") if defined?(Rails) && Rails.logger
          end
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineupTags::Patches::ProjectPatch)
  Project.send(:include, RedmineupTags::Patches::ProjectPatch)
end
