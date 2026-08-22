# frozen_string_literal: true

class TagCloudsController < ApplicationController
  helper :tags
  helper :issues_tags

  before_action :find_project_by_project_id
  before_action :authorize_tag_clouds
  before_action :find_tag_cloud, only: %i[edit update destroy]

  def index
    @tag_clouds = TagCloud.for_project(@project).to_a
  end

  def new
    @tag_cloud = TagCloud.new(
      visible_by_default: true,
      visibility: 'all',
      tag_filter: false,
      include_subprojects: false,
      status_operator: '*',
      version_operator: '*',
      tracker_operator: '*'
    )
    load_filter_options
  end

  def create
    @tag_cloud = TagCloud.new(tag_cloud_params)
    @tag_cloud.created_by = User.current
    @tag_cloud.visibility = 'all' if @tag_cloud.visibility.blank?
    apply_join_ids!(@tag_cloud)
    @tag_cloud.tag_cloud_projects.build(project: @project, position: next_position)

    if @tag_cloud.save
      redirect_after_change l(:notice_tag_cloud_created)
    else
      load_filter_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_filter_options
  end

  def update
    @tag_cloud.assign_attributes(tag_cloud_params)
    apply_join_ids!(@tag_cloud)

    if @tag_cloud.save
      redirect_after_change l(:notice_tag_cloud_updated)
    else
      load_filter_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    link = @tag_cloud.tag_cloud_projects.find_by(project_id: @project.id)
    link&.destroy
    @tag_cloud.destroy! if @tag_cloud.tag_cloud_projects.reload.empty?

    redirect_after_change l(:notice_tag_cloud_deleted)
  end

  def reorder
    ids = Array(params[:tag_cloud_ids]).map { |v| Integer(v) rescue 0 }.reject(&:zero?)
    links = @project.tag_cloud_projects.where(tag_cloud_id: ids).index_by(&:tag_cloud_id)

    TagCloudProject.transaction do
      ids.each_with_index do |id, index|
        link = links[id]
        next unless link

        link.update!(position: index) if link.position != index
      end
    end

    head :no_content
  end

  def preview
    cloud = TagCloud.new(
      status_operator: params[:status_operator].presence || '*',
      version_operator: params[:version_operator].presence || '*',
      tracker_operator: params[:tracker_operator].presence || '*',
      status_filter: Array(params[:status_filter]),
      version_filter: Array(params[:version_filter]),
      tracker_filter: Array(params[:tracker_filter]),
      tag_filter: ActiveModel::Type::Boolean.new.cast(params[:tag_filter]),
      visible_by_default: true,
      visibility: 'all',
      include_subprojects: false
    )
    cloud.tag_ids = Array(params[:tag_ids]) if cloud.tag_filter

    open_only = RedmineupTags.settings['issues_open_only'].to_i == 1
    tags = TagCloudAggregator.new(
      cloud,
      project: @project,
      user: User.current,
      open_only: open_only
    ).tags.to_a

    if tags.empty?
      render html: helpers.content_tag(:p, l(:label_tag_cloud_empty), class: 'tag-cloud-empty')
      return
    end

    style = RedmineupTags.tag_list_view
    style = :cloud if style == :none

    html = helpers.render_tags_list(
      tags,
      show_count: RedmineupTags.settings['issues_show_count'].to_i == 1,
      open_only: open_only,
      style: style
    )
    render html: html
  rescue StandardError => e
    Rails.logger.error("[redmineup_tags] preview project=#{@project&.id}: #{e.class}: #{e.message}")
    render html: helpers.content_tag(:p, l(:label_tag_cloud_empty), class: 'tag-cloud-empty')
  end

  private

  def authorize_tag_clouds
    return true if User.current.admin?

    authorize
  end

  def find_tag_cloud
    @tag_cloud = TagCloud.for_project(@project).find(params[:id])
  end

  def next_position
    (@project.tag_cloud_projects.maximum(:position) || -1) + 1
  end

  def load_filter_options
    @statuses = IssueStatus.sorted
    @trackers = @project.trackers.sorted
    versions = @project.respond_to?(:shared_versions) ? @project.shared_versions : @project.versions
    @versions = versions.where.not(status: 'closed')
    @versions = @versions.sorted if @versions.respond_to?(:sorted)
    @roles = Role.givable.sorted
    @available_tags = project_available_tags
  end

  def project_available_tags
    tags_table = Redmineup::Tag.table_name
    taggings_table = Redmineup::Tagging.table_name

    open_issue_ids = Issue
                     .joins(:status)
                     .where(project_id: @project.id)
                     .where(issue_statuses: { is_closed: false })
                     .unscope(:order, :select)
                     .distinct
                     .pluck(:id)

    return Redmineup::Tag.none if open_issue_ids.empty?

    Redmineup::Tag
      .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
      .where("#{taggings_table}.taggable_type = ?", Issue.name)
      .where("#{taggings_table}.taggable_id" => open_issue_ids)
      .distinct
      .order(Arel.sql("#{tags_table}.name ASC"))
  rescue StandardError => e
    Rails.logger.error(
      "[redmineup_tags] project_available_tags project=#{@project&.id}: #{e.class}: #{e.message}"
    )
    Redmineup::Tag.none
  end

  def tag_cloud_params
    raw = params.fetch(:tag_cloud, {}).permit(
      :name,
      :visible_by_default,
      :visibility,
      :tag_filter,
      :include_subprojects,
      :status_operator,
      :version_operator,
      :tracker_operator,
      status_filter: [],
      version_filter: [],
      tracker_filter: []
    )

    raw[:visible_by_default] = ActiveModel::Type::Boolean.new.cast(raw[:visible_by_default])
    raw[:tag_filter] = ActiveModel::Type::Boolean.new.cast(raw.fetch(:tag_filter, false))
    raw[:include_subprojects] = ActiveModel::Type::Boolean.new.cast(raw.fetch(:include_subprojects, false))
    raw[:visibility] = raw[:visibility].to_s.presence_in(TagCloud::VISIBILITIES) || 'all'
    raw[:status_operator] = raw[:status_operator].to_s.presence_in(TagCloud::STATUS_OPERATORS) || '*'
    raw[:version_operator] = raw[:version_operator].to_s.presence_in(TagCloud::VERSION_OPERATORS) || '*'
    raw[:tracker_operator] = raw[:tracker_operator].to_s.presence_in(TagCloud::TRACKER_OPERATORS) || '*'
    raw[:status_filter] = Array(raw[:status_filter])
    raw[:version_filter] = Array(raw[:version_filter])
    raw[:tracker_filter] = Array(raw[:tracker_filter])
    collapse_full_filters!(raw)
    raw
  end

  def collapse_full_filters!(raw)
    if raw[:status_operator] == '=' && filter_covers_all?(raw[:status_filter], IssueStatus.pluck(:id))
      raw[:status_operator] = '*'
      raw[:status_filter] = []
    end

    version_ids =
      begin
        scope = @project.respond_to?(:shared_versions) ? @project.shared_versions : @project.versions
        scope.where.not(status: 'closed').pluck(:id)
      rescue StandardError
        @project.versions.where.not(status: 'closed').pluck(:id)
      end
    if raw[:version_operator] == '=' && filter_covers_all?(raw[:version_filter], version_ids)
      raw[:version_operator] = '*'
      raw[:version_filter] = []
    end

    if raw[:tracker_operator] == '=' && filter_covers_all?(raw[:tracker_filter], @project.trackers.pluck(:id))
      raw[:tracker_operator] = '*'
      raw[:tracker_filter] = []
    end
  end

  def filter_covers_all?(selected, all_ids)
    sel = Array(selected).map(&:to_i).reject(&:zero?).uniq.sort
    all = Array(all_ids).map(&:to_i).reject(&:zero?).uniq.sort
    sel.any? && all.any? && sel == all
  end

  def apply_join_ids!(cloud)
    role_ids = Array(params.dig(:tag_cloud, :role_ids)).map(&:to_i).reject(&:zero?).uniq
    tag_ids  = Array(params.dig(:tag_cloud, :tag_ids)).map(&:to_i).reject(&:zero?).uniq

    if cloud.visibility == 'roles'
      cloud.role_ids = role_ids
    else
      cloud.role_ids = []
    end

    if cloud.tag_filter
      cloud.tag_ids = tag_ids
    else
      cloud.tag_ids = []
    end

    if cloud.visibility == 'owner'
      cloud.owner ||= User.current
    end
  end

  def redirect_after_change(notice)
    if from_plugin_settings?
      redirect_to(
        { controller: 'settings', action: 'plugin', id: 'redmineup_tags', tab: 'tag_clouds' },
        notice: notice
      )
    else
      redirect_to settings_project_path(@project, tab: 'tags'), notice: notice
    end
  end

  def from_plugin_settings?
    ref = request.referer.to_s
    ref.include?('/settings/plugin/redmineup_tags') ||
      ref.include?('settings/plugin') && ref.include?('redmineup_tags')
  end
end
