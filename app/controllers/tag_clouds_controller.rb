# frozen_string_literal: true

class TagCloudsController < ApplicationController
  helper :tags
  helper :issues_tags

  before_action :find_project_by_project_id
  before_action :authorize_tag_clouds
  before_action :ensure_operator_schema, only: %i[new create edit update preview]
  before_action :find_tag_cloud, only: %i[edit update destroy]

  def index
    @tag_clouds = TagCloud.for_project(@project).to_a.select do |cloud|
      cloud.listed_in_settings_for?(User.current)
    end
  end

  def new
    @tag_cloud = build_preview_cloud(
      status_operator: '*',
      version_operator: '*',
      tracker_operator: '*',
      tag_operator: '*',
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
    if @tag_cloud.linked_to?(@project)
      link = @tag_cloud.tag_cloud_projects.find_by(project_id: @project.id)
      link&.destroy
      @tag_cloud.destroy! if @tag_cloud.tag_cloud_projects.reload.empty?
    else
      @tag_cloud.destroy!
    end

    redirect_after_change l(:notice_tag_cloud_deleted)
  end

  def reorder
    ids = Array(params[:tag_cloud_ids]).map { |v| Integer(v) rescue 0 }.reject(&:zero?)
    ids = manageable_reorder_ids(ids)
    inherited = ActiveModel::Type::Boolean.new.cast(params[:inherited])

    if inherited
      reorder_inherited_clouds(ids)
    else
      reorder_local_clouds(ids)
    end

    head :no_content
  end

  def preview
    cloud = build_preview_cloud(
      status_operator: params[:status_operator].presence || '*',
      version_operator: params[:version_operator].presence || '*',
      tracker_operator: params[:tracker_operator].presence || '*',
      tag_operator: params[:tag_operator].presence || '*',
      status_filter: Array(params[:status_filter]),
      version_filter: Array(params[:version_filter]),
      tracker_filter: Array(params[:tracker_filter]),
      visible_by_default: true,
      visibility: 'all',
      include_subprojects: ActiveModel::Type::Boolean.new.cast(params[:include_subprojects])
    )
    cloud.tag_ids = Array(params[:tag_ids]) if cloud.respond_to?(:tag_ids=)

    aggregator = TagCloudAggregator.new(
      cloud,
      project: @project,
      user: User.current,
      open_only: false
    )
    tags = aggregator.tags.to_a
    untagged = aggregator.modal_issue_counts[:untagged]

    html =
      if tags.empty?
        helpers.content_tag(:p, l(:label_tag_cloud_empty), class: 'tag-cloud-empty')
      else
        style = RedmineupTags.tag_list_view
        style = :simple_cloud if style == :none || style.blank?
        helpers.render_tags_list(
          tags,
          show_count: RedmineupTags.settings['issues_show_count'].to_i == 1,
          open_only: false,
          style: style,
          tag_cloud: cloud
        )
      end

    render json: {
      html: html.to_s,
      filtered: aggregator.issue_count.to_i,
      unfiltered: untagged.to_i
    }
  rescue StandardError => e
    Rails.logger.error("[redmineup_tags] preview project=#{@project&.id}: #{e.class}: #{e.message} #{e.backtrace&.first(8)}")
    render json: {
      html: helpers.content_tag(:p, l(:label_tag_cloud_empty), class: 'tag-cloud-empty').to_s,
      filtered: 0,
      unfiltered: 0
    }
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
    %i[status_operator version_operator tracker_operator tag_operator].each do |key|
      next unless attrs.key?(key)
      next unless cloud.respond_to?("#{key}=")
      next if key != :tag_operator && !TagCloud.operator_columns?
      next if key == :tag_operator && !TagCloud.tag_operator_column?

      cloud.public_send("#{key}=", attrs[key])
    end
    %i[status_filter version_filter tracker_filter include_subprojects visibility visible_by_default].each do |key|
      next unless attrs.key?(key)
      next unless cloud.respond_to?("#{key}=")

      cloud.public_send("#{key}=", attrs[key])
    end
    cloud
  end

  def authorize_tag_clouds
    return true if User.current.admin?

    if action_name == 'index'
      deny_access unless TagCloud.can_view_settings_list?(User.current, @project)
      return true
    end

    authorize
  end

  def find_tag_cloud
    id = params[:id].to_i
    @tag_cloud = TagCloud.for_project(@project).find_by(id: id)
    @tag_cloud ||= TagCloud.inherited_for(@project).find { |cloud| cloud.id == id }
    raise ActiveRecord::RecordNotFound unless @tag_cloud
    return if User.current.admin?
    return if @tag_cloud.manageable_by?(User.current, project: @project)

    deny_access
  end

  def manageable_reorder_ids(ids)
    return ids if User.current.admin?
    return [] if ids.empty?

    allowed = TagCloud.where(id: ids).to_a.select do |cloud|
      cloud.manageable_by?(User.current, project: @project)
    end.map(&:id)
    ids.select { |id| allowed.include?(id) }
  end

  def next_position
    (@project.tag_cloud_projects.maximum(:position) || -1) + 1
  end

  def reorder_local_clouds(ids)
    links = @project.tag_cloud_projects.where(tag_cloud_id: ids).index_by(&:tag_cloud_id)

    TagCloudProject.transaction do
      ids.each_with_index do |id, index|
        link = links[id]
        next unless link

        link.update!(position: index) if link.position != index
      end
    end
  end

  def reorder_inherited_clouds(ids)
    clouds = TagCloud.inherited_for(@project)
    by_id = clouds.index_by(&:id)
    ids = ids.select { |id| by_id[id] }.uniq
    return if ids.empty?

    grouped = ids.group_by { |id| by_id[id].home_project_for(@project)&.id }
    TagCloudProject.transaction do
      grouped.each do |home_id, group_ids|
        next unless home_id

        links = TagCloudProject.where(project_id: home_id, tag_cloud_id: group_ids).index_by(&:tag_cloud_id)
        slots = group_ids.map { |id| links[id]&.position }.compact.sort
        group_ids.each_with_index do |id, index|
          link = links[id]
          next unless link

          new_pos = slots[index] || index
          link.update!(position: new_pos) if link.position != new_pos
        end
      end
    end
  end

  def load_filter_options
    @statuses = IssueStatus.sorted
    @trackers = trackers_for_filter
    @versions = active_versions_for_project
    @roles = roles_for_filter
    @available_tags = project_available_tags
  end

  def roles_for_filter
    roles = []
    if defined?(Role)
      roles = Role.givable.to_a if Role.respond_to?(:givable)
      roles = Role.where(builtin: 0).to_a if roles.blank? && Role.respond_to?(:where)
    end
    extra_ids = Array(@tag_cloud&.role_ids).map(&:to_i).reject(&:zero?)
    if extra_ids.any? && defined?(Role)
      present = roles.map(&:id)
      missing = extra_ids - present
      roles.concat(Role.where(id: missing).to_a) if missing.any?
    end
    roles.sort_by { |role| [role.respond_to?(:position) ? role.position.to_i : 0, role.name.to_s] }
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] roles_for_filter: #{e.class}: #{e.message}")
    []
  end

  def cloud_scope_project
    return @project unless @tag_cloud&.persisted?

    @tag_cloud.home_project_for(@project) || @project
  end

  def trackers_for_filter
    ids = self_and_descendant_project_ids
    scope =
      if defined?(Tracker) && Tracker.reflect_on_association(:projects)
        Tracker.joins(:projects).where(projects: { id: ids }).distinct
      else
        cloud_scope_project.trackers
      end
    scope = scope.sorted if scope.respond_to?(:sorted)
    merge_saved_records(scope, Tracker, Array(@tag_cloud&.tracker_filter))
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] trackers_for_filter: #{e.class}: #{e.message}")
    trackers = cloud_scope_project.trackers
    trackers.respond_to?(:sorted) ? trackers.sorted : trackers
  end

  def self_and_descendant_project_ids
    root = cloud_scope_project
    ids = [root.id]
    if root.respond_to?(:descendants)
      ids.concat(Array(root.descendants.pluck(:id)))
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

  def active_versions_for_project
    scope_project = cloud_scope_project
    versions = []
    if scope_project.respond_to?(:rolled_up_versions)
      versions.concat(Array(scope_project.rolled_up_versions))
    end
    if scope_project.respond_to?(:shared_versions)
      versions.concat(Array(scope_project.shared_versions))
    end
    versions.concat(Array(scope_project.versions))
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
    Array(cloud_scope_project.versions).reject { |v| v.status.to_s == 'closed' }
  end

  def project_available_tags
    tags_table = Redmineup::Tag.table_name
    taggings_table = Redmineup::Tagging.table_name
    project_ids = self_and_descendant_project_ids
    extra_ids = Array(@tag_cloud&.tag_ids).map(&:to_i).reject(&:zero?)

    issue_ids = Issue.where(project_id: project_ids).unscope(:order, :select).distinct.pluck(:id)
    records = []

    if issue_ids.any?
      records = Redmineup::Tag
                .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
                .where("#{taggings_table}.taggable_type = ?", Issue.name)
                .where("#{taggings_table}.taggable_id" => issue_ids)
                .distinct
                .to_a
    end

    if extra_ids.any?
      present = records.map(&:id)
      missing = extra_ids - present
      records.concat(Redmineup::Tag.where(id: missing).to_a) if missing.any?
    end

    records.uniq(&:id).sort_by { |tag| tag.name.to_s.downcase }
  rescue StandardError => e
    Rails.logger.error(
      "[redmineup_tags] project_available_tags project=#{@project&.id}: #{e.class}: #{e.message}"
    )
    extra_ids = Array(@tag_cloud&.tag_ids).map(&:to_i).reject(&:zero?)
    extra_ids.any? ? Redmineup::Tag.where(id: extra_ids).to_a : []
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
      :tag_operator,
      status_filter: [],
      version_filter: [],
      tracker_filter: []
    )

    raw[:visible_by_default] = ActiveModel::Type::Boolean.new.cast(raw[:visible_by_default])
    raw[:include_subprojects] = ActiveModel::Type::Boolean.new.cast(raw.fetch(:include_subprojects, false))
    raw[:visibility] = raw[:visibility].to_s.presence_in(TagCloud::VISIBILITIES) || 'all'
    raw[:status_operator] = raw[:status_operator].to_s.presence_in(TagCloud::STATUS_OPERATORS) || '*'
    raw[:version_operator] = raw[:version_operator].to_s.presence_in(TagCloud::VERSION_OPERATORS) || '*'
    raw[:tracker_operator] = raw[:tracker_operator].to_s.presence_in(TagCloud::TRACKER_OPERATORS) || '*'
    raw[:tag_operator] = raw[:tag_operator].to_s.presence_in(TagCloud::TAG_OPERATORS) || '*'
    raw[:tag_filter] = %w[= ! !*].include?(raw[:tag_operator])
    raw[:status_filter] = Array(raw[:status_filter])
    raw[:version_filter] = Array(raw[:version_filter])
    raw[:tracker_filter] = Array(raw[:tracker_filter])
    if force_without_operators || !TagCloud.operator_columns?
      raw.delete(:status_operator)
      raw.delete(:version_operator)
      raw.delete(:tracker_operator)
    end
    raw.delete(:tag_operator) if force_without_operators || !TagCloud.tag_operator_column?
    raw
  end

  def apply_join_ids!(cloud)
    role_ids = Array(params.dig(:tag_cloud, :role_ids)).map(&:to_i).reject(&:zero?).uniq
    tag_ids  = Array(params.dig(:tag_cloud, :tag_ids)).map(&:to_i).reject(&:zero?).uniq

    if cloud.visibility == 'roles'
      cloud.role_ids = role_ids
    else
      cloud.role_ids = []
    end

    if cloud.tag_needs_values?
      cloud.tag_ids = tag_ids
    else
      cloud.tag_ids = []
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
