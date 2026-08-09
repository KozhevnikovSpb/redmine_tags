# frozen_string_literal: true

# Aggregates real RedmineUP tags for a given TagCloud + Project context.
# Filters issues by status/version/tracker (and optionally by explicit tag list).
# Does not invent tags from trackers/statuses/versions.
class TagCloudAggregator
  def initialize(tag_cloud, project:, user: User.current)
    @tag_cloud = tag_cloud
    @project = project
    @user = user
  end

  def tags
    issues = Issue.visible(@user, project: @project, with_subprojects: @tag_cloud.include_subprojects)
    issues = issues.where(status_id: @tag_cloud.status_filter) if @tag_cloud.status_filter.present?
    issues = issues.where(tracker_id: @tag_cloud.tracker_filter) if @tag_cloud.tracker_filter.present?
    issues = issues.where(fixed_version_id: @tag_cloud.version_filter) if @tag_cloud.version_filter.present?

    tags_table = Redmineup::Tag.table_name
    taggings_table = Redmineup::Tagging.table_name

    scope = Redmineup::Tag
            .joins("INNER JOIN #{taggings_table} ON #{taggings_table}.tag_id = #{tags_table}.id")
            .where("#{taggings_table}.taggable_type = ?", Issue.name)
            .where("#{taggings_table}.taggable_id IN (#{issues.select(:id).to_sql})")

    if @tag_cloud.tag_filter && @tag_cloud.tag_ids.any?
      scope = scope.where("#{tags_table}.id" => @tag_cloud.tag_ids)
    end

    scope
      .select(
        "#{tags_table}.id, #{tags_table}.name, #{tags_table}.color, " \
        "COUNT(DISTINCT #{taggings_table}.taggable_id) AS count"
      )
      .group("#{tags_table}.id, #{tags_table}.name, #{tags_table}.color")
  end
end
