# frozen_string_literal: true

# Zeitwerk maps this path to RedmineupTags::Patches::TagCloudUntaggedPatch.
# Rails 8 raises if that constant is missing after the file is loaded.
module RedmineupTags
  module Patches
    module TagCloudUntaggedPatch
      def show_untagged?
        return false unless self.class.column_names.include?('show_untagged')

        ActiveModel::Type::Boolean.new.cast(self[:show_untagged])
      rescue StandardError
        false
      end
    end

    module TagCloudsControllerUntaggedPatch
      def tag_cloud_params(force_without_operators: false)
        raw = super
        return raw unless defined?(TagCloud) && TagCloud.column_names.include?('show_untagged')
        return raw unless params[:tag_cloud]&.key?(:show_untagged)

        raw[:show_untagged] = ActiveModel::Type::Boolean.new.cast(params[:tag_cloud][:show_untagged])
        raw
      end
    end
  end
end

Rails.application.config.to_prepare do
  if defined?(TagCloud) && !TagCloud.included_modules.include?(RedmineupTags::Patches::TagCloudUntaggedPatch)
    TagCloud.include RedmineupTags::Patches::TagCloudUntaggedPatch
  end

  next unless defined?(TagCloudsController)

  patch = RedmineupTags::Patches::TagCloudsControllerUntaggedPatch
  unless TagCloudsController.included_modules.include?(patch)
    TagCloudsController.prepend patch
  end
end
