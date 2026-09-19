# frozen_string_literal: true

class TagCloudSystemSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize_system_cloud

  def edit
    load_system_form
    render 'tag_clouds/edit_system'
  end

  def update
    save_system_settings!
    if params[:apply_to_all].present?
      TagCloudPreference.clear_system_overrides_for_project!(@project)
      redirect_to settings_project_path(@project, tab: 'tags'),
                  notice: l(:notice_tag_cloud_visibility_applied)
    else
      redirect_to settings_project_path(@project, tab: 'tags'),
                  notice: l(:notice_tag_cloud_updated)
    end
  end

  private

  def load_system_form
    @system_setting = TagCloudProjectSetting.record_for(@project)
    @system_visible_by_default = TagCloudProjectSetting.local_visible_by_default?(@project)
    @system_include_subprojects = TagCloudProjectSetting.local_include_subprojects?(@project)
  end

  def save_system_settings!
    include_sub = ActiveModel::Type::Boolean.new.cast(params[:include_subprojects])
    visible =
      if User.current.admin? && params.key?(:system_hidden)
        !ActiveModel::Type::Boolean.new.cast(params[:system_hidden])
      elsif User.current.admin? && params.key?(:system_visible_by_default)
        ActiveModel::Type::Boolean.new.cast(params[:system_visible_by_default])
      else
        TagCloudProjectSetting.local_visible_by_default?(@project)
      end
    TagCloudProjectSetting.update_system!(
      @project,
      visible: visible,
      include_subprojects: include_sub
    )
  end

  def authorize_system_cloud
    unless User.current.admin? || TagCloud.can_manage?(User.current, @project)
      deny_access
      return
    end
    return unless TagCloudProjectSetting.locked_by_ancestor?(@project)

    deny_access
  end
end
