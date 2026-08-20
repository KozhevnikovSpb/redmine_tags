# frozen_string_literal: true

module IssuesTagsHelper
  def sidebar_tags
    return @sidebar_tags if defined?(@sidebar_tags)

    @sidebar_tags = []
    return @sidebar_tags if RedmineupTags.tag_list_view == :none

    projects = []
    if @project
      projects << @project
      projects.concat(@project.descendants.to_a) if Setting.display_subprojects_issues?
    end

    options = {
      user: User.current,
      open_only: RedmineupTags.settings['issues_open_only'].to_i == 1
    }
    options[:projects] = projects if projects.any?

    @sidebar_tags = Issue.all_tags(options).to_a
  rescue StandardError => e
    log_tag_sidebar_error(e, 'system cloud tags')
    @sidebar_tags = []
  end

  def render_sidebar_tags
    render_tags_list(
      sidebar_tags,
      show_count: RedmineupTags.settings['issues_show_count'].to_i == 1,
      open_only: RedmineupTags.settings['issues_open_only'].to_i == 1,
      style: RedmineupTags.tag_list_view
    )
  end

  def render_tag_cloud(cloud)
    open_only = RedmineupTags.settings['issues_open_only'].to_i == 1
    # Count against the current view project (issues list scope), not cloud home.
    tags = TagCloudAggregator.new(
      cloud,
      project: @project,
      user: User.current,
      open_only: open_only
    ).tags.to_a

    return ''.html_safe if tags.empty?

    render_tags_list(
      tags,
      show_count: RedmineupTags.settings['issues_show_count'].to_i == 1,
      open_only: open_only,
      style: RedmineupTags.tag_list_view,
      tag_cloud: cloud
    )
  rescue StandardError => e
    log_tag_sidebar_error(e, "custom cloud #{cloud.id}")
    ''.html_safe
  end

  def render_tags_sidebar
    return ''.html_safe if RedmineupTags.tag_list_view == :none
    return render_global_tags_sidebar unless @project

    custom_clouds = TagCloud.for_sidebar(@project)
    can_select_clouds = User.current.allowed_to?(:select_tag_clouds, @project)

    local_clouds = TagCloud.for_project(@project).to_a
    unless can_select_clouds
      clear_stale_tag_cloud_preferences!(User.current, local_clouds)
    end

    custom_clouds = sort_tag_clouds_for_user(custom_clouds, User.current) if can_select_clouds

    visible_custom = custom_clouds.select { |c| c.visible_for?(User.current, project: @project) }

    sections = []

    sections << tag_cloud_section(
      system_tag_cloud_title,
      render_sidebar_tags,
      'sidebar-tag-cloud sidebar-tag-cloud-system'
    )

    if can_select_clouds && local_clouds.any?
      sections << content_tag(:div, class: 'sidebar-tag-cloud-controls') do
        link_to(
          l(:label_select_visible_tag_clouds),
          edit_project_tag_cloud_preferences_path(@project),
          remote: true,
          class: 'icon icon-settings'
        )
      end
    end

    visible_custom.each do |cloud|
      body = render_tag_cloud(cloud)
      next if body.blank?

      sections << tag_cloud_section(
        custom_tag_cloud_title(cloud),
        body,
        'sidebar-tag-cloud',
        data: { tag_cloud_id: cloud.id }
      )
    end

    safe_join(sections)
  rescue StandardError => e
    log_tag_sidebar_error(e, 'sidebar')
    ''.html_safe
  end

  private

  def system_tag_cloud_title
    safe_join([l(:tags), ' '.html_safe, tag_cloud_letter_marker(:system)])
  end

  def custom_tag_cloud_title(cloud)
    parts = [h(cloud.name)]
    if @project && !cloud.linked_to?(@project)
      parts << ' '.html_safe
      parts << tag_cloud_letter_marker(:inherited)
    end
    safe_join(parts)
  end

  def clear_stale_tag_cloud_preferences!(user, clouds)
    return if user.nil? || !user.logged? || clouds.blank?

    ids = clouds.map(&:id)
    return if ids.empty?

    TagCloudPreference.where(user_id: user.id, tag_cloud_id: ids).delete_all
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] clear_stale_tag_cloud_preferences: #{e.class}: #{e.message}")
  end

  def sort_tag_clouds_for_user(clouds, user)
    return clouds if user.nil? || !user.logged? || clouds.blank?
    return clouds unless @project && user.allowed_to?(:select_tag_clouds, @project)

    prefs = TagCloudPreference.where(user_id: user.id, tag_cloud_id: clouds.map(&:id)).index_by(&:tag_cloud_id)
    return clouds if prefs.empty? || prefs.values.none? { |p| !p.position.nil? }

    clouds.sort_by.with_index do |cloud, idx|
      pref = prefs[cloud.id]
      [pref&.position.nil? ? 1_000_000 + idx : pref.position, idx]
    end
  end

  def render_global_tags_sidebar
    tag_cloud_section(
      system_tag_cloud_title,
      render_sidebar_tags,
      'sidebar-tag-cloud sidebar-tag-cloud-system sidebar-tag-cloud-global'
    )
  end

  def tag_cloud_section(title, body, css_class, data: nil, extra: nil)
    options = { class: css_class }
    options[:data] = data if data

    content_tag(:div, options) do
      safe_join([
        content_tag(:h3, title),
        body,
        extra
      ].compact)
    end
  end

  def log_tag_sidebar_error(error, context)
    project_id = @project&.id || 'none'
    user_id = User.current&.id || 'anonymous'
    Rails.logger.error(
      "[redmineup_tags] Failed to render #{context} " \
      "(project=#{project_id}, user=#{user_id}): #{error.class}: #{error.message}\n" \
      "#{error.backtrace&.first(8)&.join("\n")}"
    )
  end
end
