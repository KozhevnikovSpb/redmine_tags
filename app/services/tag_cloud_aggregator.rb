# frozen_string_literal: true

# Aggregates real RedmineUP tags for a TagCloud + Project context.
#
# Rules:
# - Only real tags from taggings on Issue.
# - Empty status/version/tracker filter => no restriction.
# - tag_filter=true and no tag_cloud_tags => empty result.
# - include_subprojects:
#     false → only the cloud home project (this level only)
#     true  → home + descendants (never parents/siblings)
class TagCloudAggregator
  def initialize(tag_cloud, project:, user: User.current, open_only: false)
    @tag_cloud = tag_cloud
    @project = project
    @user = user
    @open_only = open_only
  end

  def tags
    return empty_tags if @project.nil? || @tag_cloud.nil?

    if @tag_cloud.tag_filter && Array(@tag_cloud.tag_ids).empty?
      log_empty('tag_filter enabled but whitelist empty')
      return empty_tags
    end

    project_ids = scoped_project_ids
    if project_ids.empty?
      log_empty('no project_ids')
      return empty_tags
    end

    issues = Issue.visible(@user).where(project_id: project_ids)
    if @open_only
      issues = issues.joins(:status).where(issue_statuses: { is_closed: false })
    end

    status_ids = Array(@tag_cloud.status_filter).map(&:to_i).reject(&:zero?)
    version_ids = Array(@tag_cloud.version_filter).map(&:to_i).reject(&:zero?)
    tracker_ids = Array(@tag_cloud.tracker_filter).map(&:to_i).reject(&:zero?)

    issues = issues.where(status_id: status_ids) if status_ids.any?
    issues = issues.where(tracker_id: tracker_ids) if tracker_ids.any?
    issues = issues.where(fixed_version_id: version_ids) if version_ids.any?

    # pluck avoids broken IN (SELECT ...) from Issue.visible default order/distinct
    issue_ids = issues.unscope(:order, :select).distinct.pluck(:id)
    if issue_ids.empty?
      log_empty("no visible issues in project_ids=#{project_ids.inspect} open_only=#{@open_only}")
      return empty_tags
    end

    tags_table = Redmineup::Tag.table_name
    taggings_table = Redmineup::Tagging.table_name

    scope = Redmineup::Tag
            .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
            .where("#{taggings_table}.taggable_type = ?", Issue.name)
            .where("#{taggings_table}.taggable_id" => issue_ids)

    if @tag_cloud.tag_filter
      scope = scope.where(tags_table => { id: @tag_cloud.tag_ids })
    end

    select_cols = [
      "#{tags_table}.id",
      "#{tags_table}.name",
      "COUNT(DISTINCT #{taggings_table}.taggable_id) AS count"
    ]
    group_cols = "#{tags_table}.id, #{tags_table}.name"

    if tag_has_color_column?
      select_cols.insert(2, "#{tags_table}.color")
      group_cols = "#{tags_table}.id, #{tags_table}.name, #{tags_table}.color"
    end

    result = scope.select(select_cols.join(', ')).group(group_cols)
    if result.to_a.empty?
      log_empty("issues=#{issue_ids.size} but no taggings matched")
    end
    result
  rescue StandardError => e
    Rails.logger.error(
      "[redmineup_tags] TagCloudAggregator#error cloud=#{@tag_cloud&.id} " \
      "project=#{@project&.id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    )
    empty_tags
  end

  private

  def empty_tags
    Redmineup::Tag.none
  end

  def scoped_project_ids
    return [] unless @project

    if @tag_cloud.include_subprojects?
      @project.self_and_descendants.pluck(:id)
    else
      [@project.id]
    end
  end

  def tag_has_color_column?
    return @tag_has_color if defined?(@tag_has_color)

    @tag_has_color = Redmineup::Tag.column_names.include?('color')
  rescue StandardError
    @tag_has_color = false
  end

  def log_empty(reason)
    Rails.logger.info(
      "[redmineup_tags] TagCloudAggregator empty cloud_id=#{@tag_cloud&.id} " \
      "project_id=#{@project&.id} include_subprojects=#{@tag_cloud&.include_subprojects?} " \
      "reason=#{reason}"
    )
  end
end
