# frozen_string_literal: true

module RedmineupTags
  module Patches
    module TagCloudsApplyVisibilityPatch
      def apply_visibility
        unless User.current.admin?
          deny_access
          return
        end

        TagCloud.ensure_operator_schema!
        @tag_cloud.assign_attributes(safe_tag_cloud_params)
        apply_join_ids!(@tag_cloud)
        unless @tag_cloud.save
          log_save_failure('apply_visibility')
          load_filter_options
          render :edit, status: :unprocessable_entity
          return
        end

        TagCloudPreference.reset_visibility_for_cloud!(@tag_cloud)
        redirect_after_change l(:notice_tag_cloud_visibility_applied)
      rescue ActiveModel::UnknownAttributeError
        @tag_cloud.assign_attributes(safe_tag_cloud_params(force_without_operators: true))
        apply_join_ids!(@tag_cloud)
        if @tag_cloud.save
          TagCloudPreference.reset_visibility_for_cloud!(@tag_cloud)
          redirect_after_change l(:notice_tag_cloud_visibility_applied)
        else
          log_save_failure('apply_visibility-retry')
          load_filter_options
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
