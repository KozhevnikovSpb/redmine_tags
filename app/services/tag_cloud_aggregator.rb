# frozen_string_literal: true

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

    issue_ids = matching_issue_ids
    if issue_ids.empty?
      log_empty("no visible issues open_only=#{@open_only}")
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
    log_empty("issues=#{issue_ids.size} but no taggings matched") if result.to_a.empty?
    result
  rescue StandardError => e
    Rails.logger.error(
      "[redmineup_tags] TagCloudAggregator#error cloud=#{@tag_cloud&.id} " \
      "project=#{@project&.id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    )
    empty_tags
  end

  def issue_count
    return 0 if @project.nil? || @tag_cloud.nil?
    return 0 if @tag_cloud.tag_filter && Array(@tag_cloud.tag_ids).empty?

    issue_ids = matching_issue_ids
    return 0 if issue_ids.empty?
    return issue_ids.size unless @tag_cloud.tag_filter

    taggings_table = Redmineup::Tagging.table_name
    Redmineup::Tagging
      .where(taggable_type: Issue.name)
      .where(taggable_id: issue_ids)
      .where(tag_id: @tag_cloud.tag_ids)
      .distinct
      .count(:taggable_id)
  rescue StandardError => e
    Rails.logger.error(
      "[redmineup_tags] TagCloudAggregator#issue_count cloud=#{@tag_cloud&.id} " \
      "project=#{@project&.id}: #{e.class}: #{e.message}"
    )
    0
  end

  private

  def empty_tags
    Redmineup::Tag.none
  end

  def matching_issue_ids
    project_ids = view_project_ids
    return [] if project_ids.empty?

    issues = Issue.visible(@user).where(project_id: project_ids)
    if @open_only
      issues = issues.joins(:status).where(issue_statuses: { is_closed: false })
    end

    issues = apply_status_filter(issues)
    issues = apply_tracker_filter(issues)
    issues = apply_version_filter(issues)
    issues.unscope(:order, :select).distinct.pluck(:id)
  end

  def apply_status_filter(issues)
    op = operator(:status)
    ids = ids_for(:status_filter)

    case op
    when 'o'
      issues.joins(:status).where(issue_statuses: { is_closed: false })
    when 'c'
      issues.joins(:status).where(issue_statuses: { is_closed: true })
    when '='
      ids.any? ? issues.where(status_id: ids) : issues
    when '!'
      ids.any? ? issues.where.not(status_id: ids) : issues
    when 'ev'
      ids.any? ? issues.where(id: status_ever_issue_ids(ids)) : issues
    when '!ev'
      ids.any? ? issues.where.not(id: status_ever_issue_ids(ids)) : issues
    when 'cf'
      ids.any? ? issues.where(id: status_changed_from_issue_ids(ids)) : issues
    else
      issues
    end
  end

  def apply_tracker_filter(issues)
    op = operator(:tracker)
    ids = ids_for(:tracker_filter)

    case op
    when '='
      ids.any? ? issues.where(tracker_id: ids) : issues
    when '!'
      ids.any? ? issues.where.not(tracker_id: ids) : issues
    else
      issues
    end
  end

  def apply_version_filter(issues)
    op = operator(:version)
    ids = ids_for(:version_filter)

    case op
    when '='
      ids.any? ? issues.where(fixed_version_id: ids) : issues
    when '!'
      return issues unless ids.any?

      issues.where('issues.fixed_version_id IS NULL OR issues.fixed_version_id NOT IN (?)', ids)
    when '!='
      issues.where(fixed_version_id: nil)
    else
      issues
    end
  end

  def operator(kind)
    method = "normalized_#{kind}_operator"
    return @tag_cloud.public_send(method) if @tag_cloud.respond_to?(method)

    '*'
  end

  def ids_for(attr)
    Array(@tag_cloud.public_send(attr)).map(&:to_i).reject(&:zero?)
  end

  def status_ever_issue_ids(ids)
    sids = ids.map(&:to_s)
    current_ids = Issue.where(status_id: ids).unscope(:order, :select).distinct.pluck(:id)
    historical_ids = Issue.joins(:journals).merge(
      Journal.joins(:details).where(
        journal_details: { property: 'attr', prop_key: 'status_id' }
      ).where(
        'journal_details.old_value IN (:s) OR journal_details.value IN (:s)',
        s: sids
      )
    ).unscope(:order, :select).distinct.pluck(:id)
    (current_ids + historical_ids).uniq
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] status_ever_issue_ids: #{e.class}: #{e.message}")
    Issue.where(status_id: ids).unscope(:order, :select).distinct.pluck(:id)
  end

  def status_changed_from_issue_ids(ids)
    sids = ids.map(&:to_s)
    Issue.joins(:journals).merge(
      Journal.joins(:details).where(
        journal_details: { property: 'attr', prop_key: 'status_id', old_value: sids }
      )
    ).unscope(:order, :select).distinct.pluck(:id)
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] status_changed_from_issue_ids: #{e.class}: #{e.message}")
    []
  end

  def view_project_ids
    return [] unless @project

    ids = [@project.id]
    ids.concat(@project.descendants.pluck(:id)) if Setting.display_subprojects_issues?
    ids.uniq
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
      "project_id=#{@project&.id} display_subprojects=#{Setting.display_subprojects_issues?} " \
      "reason=#{reason}"
    )
  end
end
