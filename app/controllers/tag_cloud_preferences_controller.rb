# frozen_string_literal: true

class TagCloudPreferencesController < ApplicationController
  helper :tags
  helper :issues_tags

  before_action :find_project_by_project_id
  before_action :authorize_select_tag_clouds
  before_action :find_tag_cloud, only: :toggle

  def edit
    load_custom_tag_clouds_for_user
    @visible_ids = @tag_clouds.select { |c| c.visible_for?(User.current, project: @project) }.map(&:id)
    @untagged_ids = TagCloudPreference.untagged_cloud_ids_for(User.current, @tag_clouds.map(&:id))
    @system_visible = TagCloudPreference.system_visible_for?(User.current, @project)
    @show_untagged_column = untagged_column_available?

    respond_to do |format|
      format.js
    end
  end

  def update
    if params[:reset_defaults].present?
      TagCloudPreference.reset_for_user!(User.current, @project)
      redirect_back fallback_location: project_issues_path(@project),
                    notice: l(:notice_tag_cloud_preferences_reset,
                              default: 'Personal tag cloud settings were reset to defaults.')
      return
    end

    load_custom_tag_clouds_for_user
    selected_ids = Array(params[:visible_tag_cloud_ids]).map(&:to_i)
    untagged_ids = Array(params[:untagged_tag_cloud_ids]).map(&:to_i)
    inherited_order = Array(params[:inherited_tag_cloud_order]).map(&:to_i)
    local_order = Array(params[:tag_cloud_order]).map(&:to_i)
    system_visible = params[:system_tag_cloud_visible].present?

    TagCloudPreference.transaction do
      TagCloudPreference.set_system_visible!(User.current, @project, system_visible)
      save_group_preferences!(@inherited_clouds, inherited_order, selected_ids, untagged_ids)
      save_group_preferences!(@local_clouds, local_order, selected_ids, untagged_ids)
    end

    redirect_back fallback_location: project_issues_path(@project)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[redmineup_tags] Failed to update tag cloud preferences: #{e.class}: #{e.message}")
    redirect_back fallback_location: project_issues_path(@project),
                  alert: l(:notice_failed_to_update_tag_cloud_preferences, default: 'Failed to update visible tag clouds.')
  end

  def toggle
    preference = @tag_cloud.preferences.find_or_initialize_by(user_id: User.current.id)
    current = preference.persisted? ? preference.visible? : @tag_cloud.visible_by_default?
    preference.visible = !current
    preference.save!

    redirect_back fallback_location: project_issues_path(@project)
  end

  private

  def authorize_select_tag_clouds
    deny_access unless TagCloud.can_select_display?(User.current, @project)
  end

  def find_tag_cloud
    id = params[:tag_cloud_id].to_i
    @tag_cloud = (TagCloud.inherited_for(@project) + TagCloud.for_project(@project).to_a).find { |c| c.id == id }
    raise ActiveRecord::RecordNotFound unless @tag_cloud
    deny_access unless selectable_cloud?(@tag_cloud)
  end

  def load_custom_tag_clouds_for_user
    inherited = TagCloud.inherited_for(@project).select { |cloud| selectable_cloud?(cloud) }
    local = TagCloud.for_project(@project).to_a.select { |cloud| selectable_cloud?(cloud) }
    @inherited_clouds = sort_clouds_for_user(inherited, User.current)
    @local_clouds = sort_clouds_for_user(local, User.current)
    @tag_clouds = @inherited_clouds + @local_clouds
  end

  def selectable_cloud?(cloud)
    return true if cloud.authored_by?(User.current)
    !cloud.author_only?
  end

  def untagged_column_available?
    TagCloudPreference.column_names.include?('show_untagged') &&
      TagCloudUserPreference.show_untagged?(User.current) &&
      TagCloud.can_manage?(User.current, @project)
  end

  def save_group_preferences!(clouds, order_ids, selected_ids, untagged_ids)
    return if clouds.blank?

    allowed_ids = clouds.map(&:id)
    ordered = order_ids.select { |id| allowed_ids.include?(id) }.uniq
    ordered += allowed_ids - ordered
    can_store_untagged = untagged_column_available?

    ordered.each_with_index do |cloud_id, index|
      cloud = clouds.find { |c| c.id == cloud_id }
      next unless cloud

      preference = cloud.preferences.find_or_initialize_by(user_id: User.current.id)
      preference.visible = selected_ids.include?(cloud_id)
      preference.position = index
      preference.show_untagged = untagged_ids.include?(cloud_id) if can_store_untagged
      preference.save!
    end
  end

  def sort_clouds_for_user(clouds, user)
    return clouds if user.nil? || !user.logged? || clouds.empty?

    prefs = TagCloudPreference.where(user_id: user.id, tag_cloud_id: clouds.map(&:id)).index_by(&:tag_cloud_id)
    return clouds if prefs.empty? || prefs.values.none? { |p| !p.position.nil? }

    clouds.sort_by.with_index do |cloud, idx|
      pref = prefs[cloud.id]
      [pref&.position.nil? ? 1_000_000 + idx : pref.position, idx]
    end
  end
end
