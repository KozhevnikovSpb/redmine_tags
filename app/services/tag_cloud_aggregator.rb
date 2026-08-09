# frozen_string_literal: true

# Aggregates real RedmineUP tags for a TagCloud + Project context.
#
# Rules (V.0.0.2-beta):
# - Only real tags from taggings on Issue (never invent from tracker/status/version).
# - Empty status/version/tracker filter => no restriction (all).
# - tag_filter=true and no tag_cloud_tags => empty result.
# - One issue may appear in several clouds (different filter sets).
# - include_subprojects controls Issue.visible with_subprojects.
class TagCloudAggregator
  def initialize(tag_cloud, project:, user: User.current, open_only: false)
    @tag_cloud = tag_cloud
    @project = project
    @user = user
    @open_only = open_only
  end

  def tags
    return Redmineup::Tag.none if @project.nil? || @tag_cloud.nil?

    # Explicit tag whitelist enabled but empty → nothing to show
    if @tag_cloud.tag_filter && @tag_cloud.tag_ids.empty?
      return Redmineup::Tag.none
    end

    issues = Issue.visible(@user, project: @project, with_subprojects: @tag_cloud.include_subprojects)
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
end
