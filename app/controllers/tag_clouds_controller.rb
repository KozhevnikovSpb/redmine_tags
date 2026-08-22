# frozen_string_literal: true

class TagCloudsController < ApplicationController
  helper :tags
  helper :issues_tags

  before_action :find_project_by_project_id
  before_action :authorize_tag_clouds
  before_action :ensure_operator_schema, only: %i[new create edit update preview]
  before_action :find_tag_cloud, only: %i[edit update destroy]

  def index
    @tag_clouds = TagCloud.for_project(@project).to_a
  end

  def new
    @tag_cloud = build_preview_cloud(
      status_operator: '*',
      version_operator: '*',
      tracker_operator: '*',
      visible_by_default: true,
      visibility: 'all',
      tag_filter: false,
      include_subprojects: false
    )
    load_filter_options
  end

  def create
    @tag_cloud = TagCloud.new(safe_tag_cloud_params)
    @tag_cloud.created_by = User.current
    @tag_cloud.visibility = 'all' if @tag_cloud.visibility.blank?
    apply_join_ids!(@tag_cloud)
    @tag_cloud.tag_cloud_projects.build(project: @project, position: next_position)

    if @tag_cloud.save
      redirect_after_change l(:notice_tag_cloud_created)
    else
      log_save_failure('create')
      load_filter_options
      render :new, status: :unprocessable_entity
    end
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("[redmineup_tags] create unknown attribute: #{e.message}")
    @tag_cloud = TagCloud.new(safe_tag_cloud_params(force_without_operators: true))
    @tag_cloud.created_by = User.current
    apply_join_ids!(@tag_cloud)
    @tag_cloud.tag_cloud_projects.build(project: @project, position: next_position)
    if @tag_cloud.save
      redirect_after_change l(:notice_tag_cloud_created)
    else
      log_save_failure('create-retry')
      load_filter_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_filter_options
  end

  def update
    @tag_cloud.assign_attributes(safe_tag_cloud_params)
    apply_join_ids!(@tag_cloud)

    if @tag_cloud.save
      redirect_after_change l(:notice_tag_cloud_updated)
    else
      log_save_failure('update')
      load_filter_options
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("[redmineup_tags] update unknown attribute: #{e.message}")
    @tag_cloud.assign_attributes(safe_tag_cloud_params(force_without_operators: true))
    apply_join_ids!(@tag_cloud)
    if @tag_cloud.save
      redirect_after_change l(:notice_tag_cloud_updated)
    else
      log_save_failure('update-retry')
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
    cloud = build_preview_cloud(
      status_operator: params[:status_operator].presence || '*',
      version_operator: params[:version_operator].presence || '*',
      tracker_operator: params[:tracker_operator].presence || '*',
      status_filter: Array(params[:status_filter]),
      version_filter: Array(params[:version_filter]),
      tracker_filter: Array(params[:tracker_filter]),
      tag_filter: ActiveModel::Type::Boolean.new.cast(params[:tag_filter]),
      visible_by_default: true,
      visibility: 'all',
      include_subprojects: ActiveModel::Type::Boolean.new.cast(params[:include_subprojects])
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
    style = :simple_cloud if style == :none || style.blank?

    html = helpers.render_tags_list(
      tags,
      show_count: RedmineupTags.settings['issues_show_count'].to_i == 1,
      open_only: open_only,
      style: style
    )
    render html: html
  rescue StandardError => e
    Rails.logger.error("[redmineup_tags] preview project=#{@project&.id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
    render html: helpers.content_tag(:p, l(:label_tag_cloud_empty), class: 'tag-cloud-empty')
  end

  private

  def ensure_operator_schema
    TagCloud.ensure_operator_schema!
  end

  def log_save_failure(action)
    Rails.logger.warn(
      "[redmineup_tags] tag_cloud #{action} failed project=#{@project&.id} " \
      "errors=#{@tag_cloud.errors.full_messages.join(', ')}"
    )
  end

  def build_preview_cloud(attrs)
    allowed = TagCloud.attribute_names.map(&:to_sym)
    db_attrs = attrs.select { |key, _| allowed.include?(key.to_sym) }
    cloud = TagCloud.new(db_attrs)
    %i[status_operator version_operator tracker_operator].each do |key|
      next unless attrs.key?(key)
      next unless cloud.respond_to?("#{key}=") && TagCloud.operator_columns?

      cloud.public_send("#{key}=", attrs[key])
    end
    %i[status_filter version_filter tracker_filter tag_filter include_subprojects visibility visible_by_default].each do |key|
      next unless attrs.key?(key)
      next unless cloud.respond_to?("#{key}=")

      cloud.public_send("#{key}=", attrs[key])
    end
    cloud
  end

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
    @trackers = trackers_for_filter
    @versions = active_versions_for_project
    @roles = Role.givable.sorted
    @available_tags = project_available_tags
  end

  # Root cloud must offer every tracker used in this project and descendants.
  # Subprojects often enable extra trackers that the parent does not.
  def trackers_for_filter
    ids = self_and_descendant_project_ids
    scope =
      if defined?(Tracker) && Tracker.reflect_on_association(:projects)
        Tracker.joins(:projects).where(projects: { id: ids }).distinct
      else
        @project.trackers
      end
    scope = scope.sorted if scope.respond_to?(:sorted)
    merge_saved_records(scope, Tracker, Array(@tag_cloud&.tracker_filter))
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] trackers_for_filter: #{e.class}: #{e.message}")
    @project.trackers.respond_to?(:sorted) ? @project.trackers.sorted : @project.trackers
  end

  def self_and_descendant_project_ids
    ids = [@project.id]
    if @project.respond_to?(:descendants)
      ids.concat(Array(@project.descendants.pluck(:id)))
    end
    ids.uniq
  end

  def merge_saved_records(scope, model, saved_ids)
    extra_ids = Array(saved_ids).map(&:to_i).reject(&:zero?)
    records = scope.respond_to?(:to_a) ? scope.to_a : Array(scope)
    if extra_ids.any?
      present = records.map(&:id)
      missing = extra_ids - present
      records.concat(model.where(id: missing).to_a) if missing.any?
    end
    if records.first.respond_to?(:position)
      records.sort_by { |r| [r.position.to_i, r.name.to_s] }
    else
      records.sort_by { |r| r.name.to_s }
    end
  end

  # Active versions of this project, shared versions, and descendants.
  def active_versions_for_project
    versions = []
    if @project.respond_to?(:rolled_up_versions)
      versions.concat(Array(@project.rolled_up_versions))
    end
    if @project.respond_to?(:shared_versions)
      versions.concat(Array(@project.shared_versions))
    end
    versions.concat(Array(@project.versions))
    versions = versions.uniq(&:id)
    versions.reject! { |v| v.respond_to?(:closed?) ? v.closed? : v.status.to_s == 'closed' }
    extra_ids = Array(@tag_cloud&.version_filter).map(&:to_i).reject(&:zero?)
    if extra_ids.any?
      present = versions.map(&:id)
      missing = extra_ids - present
      versions.concat(Version.where(id: missing).to_a) if missing.any?
      versions.uniq!(&:id)
    end
    versions.sort_by { |v| v.name.to_s }
  rescue StandardError
    Array(@project.versions).reject { |v| v.status.to_s == 'closed' }
  end

  def project_available_tags
    tags_table = Redmineup::Tag.table_name
    taggings_table = Redmineup::Tagging.table_name
    project_ids = self_and_descendant_project_ids

    open_issue_ids = Issue
                     .joins(:status)
                     .where(project_id: project_ids)
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

  def safe_tag_cloud_params(force_without_operators: false)
    tag_cloud_params(force_without_operators: force_without_operators)
  end

  def tag_cloud_params(force_without_operators: false)
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
    if force_without_operators || !TagCloud.operator_columns?
      raw.delete(:status_operator)
      raw.delete(:version_operator)
      raw.delete(:tracker_operator)
    end
    collapse_full_filters!(raw)
    raw
  end

  def collapse_full_filters!(raw)
    if raw[:status_operator] == '=' && filter_covers_all?(raw[:status_filter], IssueStatus.pluck(:id))
      raw[:status_operator] = '*'
      raw[:status_filter] = []
    end

    version_ids = Array(active_versions_for_project).map { |v| v.respond_to?(:id) ? v.id : v.to_i }
    if raw[:version_operator] == '=' && filter_covers_all?(raw[:version_filter], version_ids)
      raw[:version_operator] = '*'
      raw[:version_filter] = []
    end

    tracker_ids = Array(trackers_for_filter).map { |t| t.respond_to?(:id) ? t.id : t.to_i }
    if raw[:tracker_operator] == '=' && filter_covers_all?(raw[:tracker_filter], tracker_ids)
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
