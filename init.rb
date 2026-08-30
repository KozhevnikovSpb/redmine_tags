requires_redmineup version_or_higher: '1.1.10' rescue raise "\n\033[31mRedmine requires newer redmineup gem version.\nPlease update with 'bundle update redmineup'.\033[0m"

require 'redmine'

TAGS_VERSION_NUMBER = '0.0.5'
TAGS_VERSION_TYPE = 'Dev'

Redmine::Plugin.register :redmineup_tags do
  name "Redmine Multi Tags Clouds plugin (#{TAGS_VERSION_TYPE})"
  author 'RedmineUP / KozhevnikovSpb'
  description 'Redmine issues tagging support with multiple tag clouds'
  version TAGS_VERSION_NUMBER
  url 'https://github.com/KozhevnikovSpb/redmine_tags'
  author_url 'mailto:support@redmineup.com'

  requires_redmine version_or_higher: '7.0'

  settings default: {
    sidebar_tag_list_view: 'simple_cloud',
    issues_show_count: 1,
    issues_open_only: 0,
    issues_sort_by: 'name',
    use_colors: 1,
    issues_sort_order: 'asc',
    tags_suggestion_order: 'name'
  }, partial: 'tags/settings'

  # All tag/cloud permissions under Issue tracking (same module as issues).
  # view_tag_clouds: see custom clouds + read-only project list (no author-only clouds).
  # select_tag_clouds: personal sidebar show/hide and order (not other authors' owner clouds).
  # manage_tag_clouds: create/edit/delete/reorder; author may edit/delete own author-only cloud.
  # Project UI never shows another user's author-only cloud, including to Redmine admin.
  # Full Redmine admin manages other authors' owner clouds only from the plugin settings list.
  project_module :issue_tracking do
    permission :create_tags, {}
    permission :edit_tags, {}
    permission :view_tag_clouds, {
      tag_clouds: %i[index]
    }
    permission :select_tag_clouds, {
      tag_cloud_preferences: %i[toggle edit update]
    }
    permission :manage_tag_clouds, {
      tag_clouds: %i[index new create edit update destroy reorder preview]
    }, require: :member
  end

  menu :admin_menu, :tags,
       { controller: 'settings', action: 'plugin', id: 'redmineup_tags' },
       caption: :tags,
       html: { class: 'icon' },
       icon: 'tag',
       plugin: :redmineup_tags
end

module RedmineupTags
  module Patches
    module ProjectsHelperPatch
      def self.included(base)
        base.class_eval do
          alias_method :project_settings_tabs_without_tags, :project_settings_tabs

          def project_settings_tabs
            tabs = project_settings_tabs_without_tags
            if TagCloud.can_view_settings_list?(User.current, @project) &&
               !tabs.any? { |tab| tab[:name] == 'tags' }
              tabs << {
                name: 'tags',
                action: User.current.allowed_to?(:manage_tag_clouds, @project) ? :manage_tag_clouds : :view_tag_clouds,
                module: :issue_tracking,
                partial: 'projects/settings/tags',
                label: :tag_clouds
              }
            end
            tabs
          end
        end
      end
    end
  end
end

unless ProjectsHelper.included_modules.include?(RedmineupTags::Patches::ProjectsHelperPatch)
  ProjectsHelper.include RedmineupTags::Patches::ProjectsHelperPatch
end

if Rails.configuration.respond_to?(:autoloader) && Rails.configuration.autoloader == :zeitwerk
  Rails.autoloaders.each { |loader| loader.ignore(File.dirname(__FILE__) + '/lib') }
end

require File.dirname(__FILE__) + '/lib/redmineup_tags'

ActiveSupport.on_load(:action_view) do
  include TagsHelper
end
