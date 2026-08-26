# frozen_string_literal: true

module RedmineupTags
  module Patches
    module TagCloudsControllerPatch
      def index
        @tag_clouds = TagCloud.for_project(@project).to_a.select do |cloud|
          cloud.listed_in_settings_for?(User.current)
        end
      end

      def authorize_tag_clouds
        return true if User.current.admin?

        if action_name == 'index'
          deny_access unless TagCloud.can_view_settings_list?(User.current, @project)
          return true
        end

        authorize
      end

      def find_tag_cloud
        id = params[:id].to_i
        @tag_cloud = TagCloud.for_project(@project).find_by(id: id)
        @tag_cloud ||= TagCloud.inherited_for(@project).find { |cloud| cloud.id == id }
        raise ActiveRecord::RecordNotFound unless @tag_cloud
        return if User.current.admin?

        deny_access unless @tag_cloud.manageable_by?(User.current, project: @project)
      end
    end
  end
end

Rails.configuration.to_prepare do
  if defined?(TagCloudsController) &&
     !TagCloudsController.included_modules.include?(RedmineupTags::Patches::TagCloudsControllerPatch)
    TagCloudsController.prepend RedmineupTags::Patches::TagCloudsControllerPatch
  end
end
