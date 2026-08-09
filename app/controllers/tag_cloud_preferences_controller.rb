# frozen_string_literal: true

class TagCloudPreferencesController < ApplicationController
  helper :tags
  helper :issues_tags

  before_action :find_project_by_project_id
  before_action :authorize_select_tag_clouds
  before_action :find_tag_cloud, only: :toggle

  def edit
    load_custom_tag_clouds
    @visible_ids = @tag_clouds.select { |c| c.visible_for?(User.current, project: @project) }.map(&:id)

    respond_to do |format|
      format.js
    end
  end

  def update
    load_custom_tag_clouds
    selected_ids = Array(params[:visible_tag_cloud_ids]).map(&:to_i)
    order_ids = Array(params[:tag_cloud_order]).map(&:to_i)

    TagCloudPreference.transaction do
      @tag_clouds.each do |cloud|
        preference = cloud.preferences.find_or_initialize_by(user: User.current)
        preference.visible = selected_ids.include?(cloud.id)
        preference.save!
      end

      apply_cloud_order(order_ids) if order_ids.any?
    end

    redirect_back fallback_location: project_issues_path(@project)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[redmineup_tags] Failed to update tag cloud preferences: #{e.class}: #{e.message}")
    redirect_back fallback_location: project_issues_path(@project),
                  alert: l(:notice_failed_to_update_tag_cloud_preferences, default: 'Failed to update visible tag clouds.')
  end

  def toggle
    preference = @tag_cloud.preferences.find_or_initialize_by(user: User.current)
    current = preference.persisted? ? preference.visible? : @tag_cloud.visible_by_default?
    preference.visible = !current
    preference.save!

    redirect_back fallback_location: project_issues_path(@project)
  end

  private

  def authorize_select_tag_clouds
    deny_access unless User.current.allowed_to?(:select_tag_clouds, @project)
  end

  def find_tag_cloud
    @tag_cloud = TagCloud.for_project(@project).find(params[:tag_cloud_id])
  end

  def load_custom_tag_clouds
    @tag_clouds = TagCloud.for_project(@project).to_a
  end

  def apply_cloud_order(order_ids)
    links = @project.tag_cloud_projects.where(tag_cloud_id: order_ids).index_by(&:tag_cloud_id)
    ordered = order_ids.select { |id| links.key?(id) }.uniq
    ordered += @tag_clouds.map(&:id) - ordered

    ordered.each_with_index do |id, index|
      link = links[id] || @project.tag_cloud_projects.find_by(tag_cloud_id: id)
      next unless link

      link.update!(position: index) if link.position != index
    end
  end
end
