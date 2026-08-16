# frozen_string_literal: true

# Aggregates real RedmineUP tags for a TagCloud + Project context.
#
# Rules:
# - Only real tags from taggings on Issue (never invent from tracker/status/version).
# - Empty status/version/tracker filter => no restriction (all).
# - tag_filter=true and no tag_cloud_tags => empty result.
# - include_subprojects:
#     false → only issues of the cloud's home project (this level only)
#     true  → home project + its descendants (never parent/sibling projects)
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
      return empty_tags
    end

    project_ids = scoped_project_ids
    return empty_tags if project_ids.empty?

    issues = Issue.visible(@user).where(project_id: project_ids)

    if @open_only
      issues = issues.joins(:status).where(issue_statuses: { is_closed: false })
    end
    issues = issues.where(status_id: @tag_cloud.status_filter) if @tag_cloud.status_filter.present?
    issues = issues.where(tracker_id: @tag_cloud.tracker_filter) if @tag_cloud.tracker_filter.present?
    issues = issues.where(fixed_version_id: @tag_cloud.version_filter) if @tag_cloud.version_filter.present?

    tags_table = Redmineup::Tag.table_name
    taggings_table = Redmineup::Tagging.table_name

    scope = Redmineup::Tag
            .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
            .where("#{taggings_table}.taggable_type = ?", Issue.name)
            .where("#{taggings_table}.taggable_id IN (#{issues.select(:id).to_sql})")

    if @tag_cloud.tag_filter
      scope = scope.where(tags_table => { id: @tag_cloud.tag_ids })
    end

    scope
      .select(
        "#{tags_table}.id, #{tags_table}.name, #{tags_table}.color, " \
        "COUNT(DISTINCT #{taggings_table}.taggable_id) AS count"
      )
      .group("#{tags_table}.id, #{tags_table}.name, #{tags_table}.color")
  end

  private

  def empty_tags
    Redmineup::Tag.none
  end

  # Never includes parent projects. Subproject clouds stay at their own level
  # (or own level + their descendants when include_subprojects is set).
  def scoped_project_ids
    return [] unless @project

    if @tag_cloud.include_subprojects?
      @project.self_and_descendants.pluck(:id)
    else
      [@project.id]
    end
  end
end
