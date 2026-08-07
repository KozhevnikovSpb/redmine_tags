class TagCloudPreferencesController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize_select_tag_clouds
  before_action :find_tag_cloud, only: :toggle

  # GET /projects/:project_id/tag_cloud_preferences/edit (JS)
  # Modal shows only custom (non-system) tag clouds.
  # System/Default cloud is always shown and is not managed here.
  def edit
    TagCloud.ensure_system_cloud(@project)
    load_custom_tag_clouds
    @visible_ids = @tag_clouds.select { |c| c.visible_for?(User.current) }.map(&:id)

    respond_to do |format|
      format.js
    end
  end

  # PUT/PATCH /projects/:project_id/tag_cloud_preferences
  # Bulk update visibility + display order for custom clouds.
  def update
    TagCloud.ensure_system_cloud(@project)
    load_custom_tag_clouds
    selected_ids = Array(params[:visible_tag_cloud_ids]).map(&:to_i)
    order_ids = Array(params[:tag_cloud_order]).map(&:to_i)

    TagCloudPreference.transaction do
      # Visibility per user
      @tag_clouds.each do |cloud|
        preference = cloud.preferences.find_or_initialize_by(user: User.current)
        preference.visible = selected_ids.include?(cloud.id)
        preference.save!
      end

      # Project-wide display order (position) from drag-and-drop
      apply_cloud_order(order_ids) if order_ids.any?
    end

    redirect_back fallback_location: project_issues_path(@project)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[redmineup_tags] Failed to update tag cloud preferences: #{e.class}: #{e.message}")
    redirect_back fallback_location: project_issues_path(@project),
                  alert: l(:notice_failed_to_update_tag_cloud_preferences, default: 'Failed to update visible tag clouds.')
  end

  # POST /projects/:project_id/tag_clouds/:tag_cloud_id/preference/toggle
  # Kept for API compatibility; UI no longer uses individual toggle.
  def toggle
    return if @tag_cloud.is_system?

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

  # Only non-system clouds. System cloud is always visible and not listed in modal.
  def load_custom_tag_clouds
    @tag_clouds = @project.tag_clouds.unscoped
                          .where(is_system: false)
                          .order(:position, :id)
                          .to_a
  end

  # Reorder custom clouds by position; system cloud stays at position 0.
  def apply_cloud_order(order_ids)
    allowed = @tag_clouds.index_by(&:id)
    # Keep only known custom cloud ids, preserve drag order
    ordered = order_ids.select { |id| allowed.key?(id) }.uniq
    # Append any custom clouds missing from the payload (safety)
    ordered += @tag_clouds.map(&:id) - ordered

    ordered.each_with_index do |id, index|
      cloud = allowed[id]
      next unless cloud

      # System stays at 0; custom start from 1
      new_position = index + 1
      cloud.update!(position: new_position) if cloud.position != new_position
    end
  end
end
