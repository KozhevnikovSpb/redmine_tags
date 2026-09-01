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

require 'digest'

module Redmineup
  module ActsAsTaggable
    module Taggable
      module SingletonMethods
        def available_tags_with_configurable_limit options = {}
          available_tags_without_configurable_limit options.merge({limit: 100})
        end

        alias_method :available_tags_without_configurable_limit, :available_tags
        alias_method :available_tags, :available_tags_with_configurable_limit
      end
    end
  end
end

module RedmineupTags
  PROJECT_MODULE_NAME = 'redmineup_tags'

  def self.settings() Setting[:plugin_redmineup_tags].stringify_keys end

  def self.use_colors?
    settings['use_colors'].to_i > 0
  end

  # Soften raw tag colors for display. Hue is kept so the same tag stays recognizable.
  def self.display_tag_color(tag_or_hex)
    hex = extract_tag_hex(tag_or_hex)
    mute_hex(hex)
  end

  def self.extract_tag_hex(tag_or_hex)
    raw =
      if tag_or_hex.respond_to?(:color)
        tag_or_hex.color.to_s
      else
        tag_or_hex.to_s
      end
    raw = raw.delete('#')
    return "##{raw}" if raw.match?(/\A[0-9a-fA-F]{6}\z/)

    name = tag_or_hex.respond_to?(:name) ? tag_or_hex.name.to_s : tag_or_hex.to_s
    "##{Digest::MD5.hexdigest(name)[0, 6]}"
  end

  def self.mute_hex(hex)
    r, g, b = hex.delete('#').scan(/../).map { |part| part.to_i(16) / 255.0 }
    h, s, l = rgb_to_hsl(r, g, b)
    s = [[s * 0.72, 0.50].max, 0.68].min
    l = [[0.58 + (l - 0.5) * 0.25, 0.52].max, 0.70].min
    nr, ng, nb = hsl_to_rgb(h, s, l)
    format('#%02x%02x%02x', (nr * 255).round, (ng * 255).round, (nb * 255).round)
  rescue StandardError
    '#93c5fd'
  end

  def self.rgb_to_hsl(r, g, b)
    max = [r, g, b].max
    min = [r, g, b].min
    l = (max + min) / 2.0
    return [0.0, 0.0, l] if max == min

    d = max - min
    s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)
    h =
      case max
      when r then ((g - b) / d + (g < b ? 6 : 0)) / 6.0
      when g then ((b - r) / d + 2) / 6.0
      else ((r - g) / d + 4) / 6.0
      end
    [h, s, l]
  end

  def self.hsl_to_rgb(h, s, l)
    return [l, l, l] if s <= 0

    q = l < 0.5 ? l * (1 + s) : l + s - l * s
    p = 2 * l - q
    [hue_to_rgb(p, q, h + 1.0 / 3), hue_to_rgb(p, q, h), hue_to_rgb(p, q, h - 1.0 / 3)]
  end

  def self.hue_to_rgb(p, q, t)
    t += 1 if t < 0
    t -= 1 if t > 1
    return p + (q - p) * 6 * t if t < 1.0 / 6
    return q if t < 1.0 / 2
    return p + (q - p) * (2.0 / 3 - t) * 6 if t < 2.0 / 3

    p
  end

  VALID_TAG_LIST_VIEWS = %i[none list cloud simple_cloud].freeze

  def self.tag_list_view
    value = settings['sidebar_tag_list_view'].to_s.strip.to_sym
    VALID_TAG_LIST_VIEWS.include?(value) ? value : :none
  end

  def self.agile_required_version?(version, type = nil)
    plugin = Redmine::Plugin.find(:redmine_agile)
    return false if plugin.version < version
    type.nil? || plugin.name.match?(/#{type}/i)
  rescue Redmine::PluginNotFound
    false
  end

  def self.enable_project_module!
    conn = ActiveRecord::Base.connection
    return unless conn.data_source_exists?('enabled_modules')

    conn.execute(<<~SQL.squish)
      INSERT INTO enabled_modules (project_id, 'redmineup_tags')
      SELECT em.project_id, 'redmineup_tags'
      FROM enabled_modules em
      WHERE em.name = 'issue_tracking'
        AND NOT EXISTS (
          SELECT 1 FROM enabled_modules em2
          WHERE em2.project_id = em.project_id
            AND em2.name = 'redmineup_tags'
        )
    SQL
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] enable_project_module: #{e.class}: #{e.message}") if defined?(Rails) && Rails.logger
  end
end

REDMINEUP_TAGS_REQUIRED_FILES = [
  'redmineup_tags/hooks/model_issue_hook',
  'redmineup_tags/hooks/views_context_menus_hook',
  'redmineup_tags/hooks/views_issues_hook',
  'redmineup_tags/hooks/views_layouts_hook',
  'redmineup_tags/patches/add_helpers_for_issue_tags_patch',
  'redmineup_tags/patches/auto_completes_controller_patch',
  'redmineup_tags/patches/issue_patch',
  'redmineup_tags/patches/issue_query_patch',
  'redmineup_tags/patches/queries_helper_patch',
  'redmineup_tags/patches/time_entry_query_patch',
  'redmineup_tags/patches/time_report_patch',
  'redmineup_tags/patches/time_entry_patch',
  'query_tags_column',
  'redmineup_tags/patches/reports_controller_patch',
  'redmineup_tags/hooks/views_reports_hook',
  'redmineup_tags/patches/project_patch',
  'redmineup_tags/schema_repair'
]

if Redmine::Plugin.installed?(:redmine_agile) &&
  Gem::Version.new(Redmine::Plugin.find(:redmine_agile).version) >= Gem::Version.new('1.4.3') && AGILE_VERSION_TYPE == 'PRO version'
  REDMINEUP_TAGS_REQUIRED_FILES << 'redmineup_tags/patches/agile_query_patch'
  REDMINEUP_TAGS_REQUIRED_FILES << 'redmineup_tags/patches/agile_versions_query_patch'
end

base_url = File.dirname(__FILE__)
REDMINEUP_TAGS_REQUIRED_FILES.each { |file| require(base_url + '/' + file) }

Rails.application.config.after_initialize do
  RedmineupTags.enable_project_module!
end
