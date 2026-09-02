# frozen_string_literal: true

class TagCloud
  def show_untagged?
    return false unless self.class.column_names.include?('show_untagged')

    ActiveModel::Type::Boolean.new.cast(self[:show_untagged])
  rescue StandardError
    false
  end
end

module RedmineupTags
  module Patches
    module TagCloudsControllerUntaggedPatch
      def tag_cloud_params(force_without_operators: false)
        raw = super
        return raw unless TagCloud.column_names.include?('show_untagged')
        return raw unless params[:tag_cloud]&.key?(:show_untagged)

        raw[:show_untagged] = ActiveModel::Type::Boolean.new.cast(params[:tag_cloud][:show_untagged])
        raw
      end
    end
  end
end

if defined?(TagCloudsController) &&
   !TagCloudsController.included_modules.include?(RedmineupTags::Patches::TagCloudsControllerUntaggedPatch)
  TagCloudsController.prepend RedmineupTags::Patches::TagCloudsControllerUntaggedPatch
end
