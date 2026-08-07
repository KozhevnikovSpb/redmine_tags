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
    tags = TagCloudAggregator.new(cloud, user: User.current).tags.to_a
    render_tags_list(
      tags,
      show_count: RedmineupTags.settings['issues_show_count'].to_i == 1,
      open_only: false,
      style: RedmineupTags.tag_list_view
    )
  rescue StandardError => e
    log_tag_sidebar_error(e, "custom cloud #{cloud.id}")
    ''.html_safe
  end

  def render_tags_sidebar
    return ''.html_safe if RedmineupTags.tag_list_view == :none
    return render_global_tags_sidebar unless @project

    clouds = TagCloud.unscoped.where(project_id: @project.id).order(:position, :id).to_a
    system_cloud = clouds.detect(&:is_system?)
    custom_clouds = clouds.reject(&:is_system?)
    can_select_clouds = User.current.allowed_to?(:select_tag_clouds, @project)
    visible_clouds, hidden_clouds = custom_clouds.partition { |cloud| cloud.visible_for?(User.current) }
    sections = []

    # Header / control for selecting visible clouds (UI modal)
    if can_select_clouds && clouds.any?
      sections << content_tag(:div, class: 'sidebar-tag-cloud-controls') do
        link_to(
          l(:label_select_visible_tag_clouds),
          edit_project_tag_cloud_preferences_path(@project),
          remote: true,
          class: 'icon icon-settings',
          title: l(:label_select_visible_tag_clouds)
        )
      end
    end

    if system_cloud.nil? || system_cloud.visible_for?(User.current)
      sections << tag_cloud_section(
        system_cloud&.name || l(:tags),
        render_sidebar_tags,
        'sidebar-tag-cloud sidebar-tag-cloud-system'
      )
    end

    visible_clouds.each do |cloud|
      extra = nil
      if can_select_clouds
        extra = content_tag(:p, class: 'small') do
          link_to(
            l(:button_hide),
            toggle_project_tag_cloud_preference_path(@project, cloud),
            method: :post,
            class: 'icon icon-close'
          )
        end
      end

      sections << tag_cloud_section(
        cloud.name,
        render_tag_cloud(cloud),
        'sidebar-tag-cloud',
        data: { tag_cloud_id: cloud.id },
        extra: extra
      )
    end

    # Keep compact list of hidden clouds + link to full modal
    sections << hidden_tag_clouds_section(hidden_clouds) if can_select_clouds && hidden_clouds.any?

    safe_join(sections)
  rescue StandardError => e
    log_tag_sidebar_error(e, 'sidebar')
    ''.html_safe
  end

  private

  def render_global_tags_sidebar
    tag_cloud_section(
      l(:tags),
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

  def hidden_tag_clouds_section(clouds)
    items = clouds.map do |cloud|
      content_tag(:li, data: { tag_cloud_id: cloud.id }) do
        safe_join([
          content_tag(:span, cloud.name),
          link_to(
            l(:button_show),
            toggle_project_tag_cloud_preference_path(@project, cloud),
            method: :post,
            class: 'icon icon-add'
          )
        ], ' ')
      end
    end

    content_tag(:div, class: 'sidebar-tag-cloud sidebar-tag-cloud-hidden') do
      safe_join([
        content_tag(:h3, l(:label_hidden_tag_clouds)),
        content_tag(:ul, safe_join(items)),
        content_tag(:p, class: 'small') do
          link_to(
            l(:label_select_visible_tag_clouds),
            edit_project_tag_cloud_preferences_path(@project),
            remote: true,
            class: 'icon icon-settings'
          )
        end
      ])
    end
  end

  def log_tag_sidebar_error(error, context)
    project_id = @project&.id || 'none'
    user_id = User.current&.id || 'anonymous'
    Rails.logger.error(
      "[redmineup_tags] Failed to render #{context} " \
      "(project=#{project_id}, user=#{user_id}): #{error.class}: #{error.message}"
    )
  end
end
