class TagCloudPreferencesController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize_select_tag_clouds
  before_action :find_tag_cloud, only: :toggle

  # GET /projects/:project_id/tag_cloud_preferences/edit (JS)
  # Renders the modal with checkboxes of all project tag clouds.
  def edit
    TagCloud.ensure_system_cloud(@project)
    @tag_clouds = @project.tag_clouds.unscoped.order(:position, :id).to_a
    @visible_ids = @tag_clouds.select { |c| c.visible_for?(User.current) }.map(&:id)

    respond_to do |format|
      format.js
    end
  end

  # PUT/PATCH /projects/:project_id/tag_cloud_preferences
  # Bulk update visibility preferences from the modal form.
  def update
    TagCloud.ensure_system_cloud(@project)
    clouds = @project.tag_clouds.unscoped.to_a
    selected_ids = Array(params[:visible_tag_cloud_ids]).map(&:to_i)

    TagCloudPreference.transaction do
      clouds.each do |cloud|
        preference = cloud.preferences.find_or_initialize_by(user: User.current)
        preference.visible = selected_ids.include?(cloud.id)
        preference.save!
      end
    end

    redirect_back fallback_location: project_issues_path(@project),
                  notice: l(:notice_tag_cloud_preferences_updated, default: 'Visible tag clouds updated.')
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[redmineup_tags] Failed to update tag cloud preferences: #{e.class}: #{e.message}")
    redirect_back fallback_location: project_issues_path(@project),
                  alert: l(:notice_failed_to_update_tag_cloud_preferences, default: 'Failed to update visible tag clouds.')
  end

  # POST /projects/:project_id/tag_clouds/:tag_cloud_id/preference/toggle
  # Legacy single-cloud toggle (kept for compatibility).
  def toggle
    preference = @tag_cloud.preferences.find_or_initialize_by(user: User.current)
    current_visibility = preference.persisted? ? preference.visible? : @tag_cloud.visible_by_default?
    preference.visible = !current_visibility
    preference.save!

    redirect_back fallback_location: project_issues_path(@project)
  end

  private

  def authorize_select_tag_clouds
    deny_access unless User.current.allowed_to?(:select_tag_clouds, @project)
  end

  def find_tag_cloud
    @tag_cloud = @project.tag_clouds.unscoped.find(params[:tag_cloud_id])
  end
end
