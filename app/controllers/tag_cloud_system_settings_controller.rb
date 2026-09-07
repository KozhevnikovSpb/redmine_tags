# frozen_string_literal: true

class TagCloudSystemSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize_system_cloud

  def edit
    @system_setting = TagCloudProjectSetting.record_for(@project)
    @system_visible_by_default = TagCloudProjectSetting.local_visible_by_default?(@project)
    @system_include_subprojects = TagCloudProjectSetting.local_include_subprojects?(@project)
    render 'tag_clouds/edit_system'
  end

  def update
    visible = ActiveModel::Type::Boolean.new.cast(params[:system_visible_by_default])
    include_sub = ActiveModel::Type::Boolean.new.cast(params[:include_subprojects])
    TagCloudProjectSetting.update_system!(
      @project,
      visible: visible,
      include_subprojects: include_sub
    )
    redirect_to settings_project_path(@project, tab: 'tags'),
                notice: l(:notice_tag_cloud_updated)
  end

  private

  def authorize_system_cloud
    unless User.current.admin? || TagCloud.can_manage?(User.current, @project)
      deny_access
      return
    end
    return unless TagCloudProjectSetting.locked_by_ancestor?(@project)

    deny_access
  end
end
