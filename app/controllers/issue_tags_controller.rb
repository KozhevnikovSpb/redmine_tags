class IssueTagsController < ApplicationController
  before_action :find_issues, only: %i[edit update]
  before_action :authorize_tag_editing, only: %i[edit update]

  def edit
    @issue_ids = Array(params[:ids] || params[:id])
    @is_bulk_editing = @issue_ids.size > 1
    @most_used_tags = Issue.all_tags(user: User.current, projects: @projects, sort_by: 'count', order: 'DESC').limit(10)
  end

  def update
    tags = Array(params.dig(:issue, :tag_list)).reject(&:blank?).uniq

    unless User.current.allowed_to?(:create_tags, @projects) || Issue.allowed_tags?(tags)
      flash[:error] = t(:notice_failed_to_add_tags)
      return redirect_to_referer_or { render plain: 'Tags were not updated.', status: :unprocessable_entity }
    end

    if update_tags(@issues, tags)
      flash[:notice] = t(:notice_tags_added)
    else
      flash[:error] = t(:notice_failed_to_add_tags)
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[redmineup_tags] Failed to update issue tags: #{e.class}: #{e.message}")
    flash[:error] = t(:notice_failed_to_add_tags)
  ensure
    redirect_to_referer_or { render plain: 'Tags updated.', layout: true } unless performed?
  end

  def autocomplete
    tags_table = Redmineup::Tag.table_name
    q = (params[:q] || params[:term]).to_s.strip
    scope = Redmineup::Tag.unscoped
    if q.present?
      scope = scope.where("LOWER(#{tags_table}.name) LIKE LOWER(?)",
                          "%#{Redmineup::Tag.sanitize_sql_like(q)}%")
    end
    scope = scope.order(Arel.sql("#{tags_table}.name ASC"))
    payload = scope.map { |tag| { id: tag.name, text: tag.name } }

    if params[:page].present?
      render json: { results: payload, pagination: { more: false } }
    else
      render json: payload
    end
  end

  private

  def authorize_tag_editing
    deny_access unless User.current.allowed_to?(:edit_tags, @projects)
  end

  def update_tags(issues, tags)
    if (tags.present? && issues.size > 1) || params[:add_only]
      add_issues_tags(issues, tags)
    else
      update_issues_tags(issues, tags)
    end
  end

  def add_issues_tags(issues, tags)
    Issue.transaction do
      issues.each do |issue|
        issue.tag_list = (issue.tag_list + tags).uniq
        issue.save!
      end
    end
    true
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def update_issues_tags(issues, tags)
    Issue.transaction do
      issues.each do |issue|
        issue.tag_list = tags
        issue.save!
      end
    end
    true
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
