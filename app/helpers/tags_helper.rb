module TagsHelper
  include Redmineup::TagsHelper

  def render_issue_tag_link(tag, options = {})
    filters = issue_filters_for_tag_link(tag, options)

    content =
      if options[:use_search]
        link_to(tag, controller: 'search', action: 'index', id: @project, q: tag.name, wiki_pages: true, issues: true)
      else
        link_to_issue_filter(tag, filters)
      end
    content << content_tag('span', "(#{tag.count})", class: 'tag-count') if options[:show_count]
    style = RedmineupTags.use_colors? ? { class: 'tag-label-color', style: "background-color: #{tag.color}" } : { class: 'tag-label' }
    content_tag('span', content, style)
  end

  def issue_filters_for_tag_link(tag, options = {})
    filters = []
    cloud = options[:tag_cloud]

    if cloud
      status_ids = Array(cloud.status_filter).map(&:to_i).reject(&:zero?)
      tracker_ids = Array(cloud.tracker_filter).map(&:to_i).reject(&:zero?)
      version_ids = Array(cloud.version_filter).map(&:to_i).reject(&:zero?)
      sop = cloud.respond_to?(:normalized_status_operator) ? cloud.normalized_status_operator : '*'
      top = cloud.respond_to?(:normalized_tracker_operator) ? cloud.normalized_tracker_operator : '*'
      vop = cloud.respond_to?(:normalized_version_operator) ? cloud.normalized_version_operator : '*'

      case sop
      when 'o', 'c'
        filters << ['status_id', sop, '']
      when '=', '!', 'ev', '!ev', 'cf'
        filters << ['status_id', sop, status_ids] if status_ids.any?
      # '*' (Any): no status constraint. Plugin issues_open_only does not apply.
      end

      if %w[= ! ev !ev cf].include?(top) && tracker_ids.any?
        filters << ['tracker_id', top, tracker_ids]
      end

      if %w[= ! ev !ev cf].include?(vop) && version_ids.any?
        filters << ['fixed_version_id', vop, version_ids]
      elsif vop == '!='
        filters << ['fixed_version_id', '!*', '']
      end
    elsif options[:open_only]
      filters << ['status_id', 'o', '']
    end

    filters << ['issue_tags', '=', tag.name]
    filters
  end

  def render_tags_list(tags, options = {})
    return if tags.nil? || tags.empty?

    content = +''
    style = options.delete(:style)
    tags = tags.to_a
    custom_cloud = options[:tag_cloud]

    case sorting = "#{RedmineupTags.settings['issues_sort_by']}:#{RedmineupTags.settings['issues_sort_order']}"
    when 'name:asc' then tags.sort_by! { |tag| tag.name.to_s.downcase }
    when 'name:desc' then tags.sort_by! { |tag| tag.name.to_s.downcase }.reverse!
    when 'count:asc'
      tags.sort_by! do |tag|
        custom_cloud ? [tag.count.to_i, tag.name.to_s.downcase] : tag.count.to_i
      end
    when 'count:desc'
      if custom_cloud
        tags.sort_by! { |tag| [-tag.count.to_i, tag.name.to_s.downcase] }
      else
        tags.sort_by! { |tag| tag.count.to_i }.reverse!
      end
    else
      logger.warn "[redmine_tags] Unknown sorting option: <#{sorting}>"
      tags.sort_by! { |tag| tag.name.to_s.downcase }
    end

    list_el, item_el =
      case style
      when :list then %w[ul li]
      when :simple_cloud, :cloud then %w[div span]
      else raise 'Unknown list style'
      end

    content = content.html_safe
    if style == :list && RedmineupTags.settings['issues_sort_by'] == 'name'
      tags.group_by { |tag| tag.name.to_s.downcase.first || '#' }.each do |letter, grouped_tags|
        content << content_tag(item_el, letter.upcase, class: 'letter', style: '')
        add_tags(style, grouped_tags, content, item_el, options)
      end
    else
      add_tags(style, tags, content, item_el, options)
    end

    content_tag(list_el, content, class: 'tags-cloud', style: (style == :simple_cloud ? 'text-align: left;' : ''))
  end

  def link_to_issue_filter(title, filters, extra = {})
    filter_params = link_to_issue_filter_options(filters).merge(extra)
    path =
      if @project
        project_issues_path(@project, filter_params)
      else
        issues_path(filter_params)
      end
    link_to title, path
  end

  def link_to_issue_filter_options(filters)
    f = []
    op = {}
    v = {}

    Array(filters).each do |name, operator, value|
      name = name.to_s
      f << name
      op[name] = operator.to_s
      v[name] = value.nil? || value == '' ? [''] : Array(value).map(&:to_s)
    end

    { set_filter: 1, f: f, op: op, v: v }
  end

  def tag_cloud_status_operator_options
    [
      [l(:label_open_issues), 'o'],
      [l(:label_equals), '='],
      [l(:label_not_equals), '!'],
      [l(:label_has_been), 'ev'],
      [l(:label_has_never_been), '!ev'],
      [l(:label_changed_from), 'cf'],
      [l(:label_closed_issues), 'c'],
      [l(:label_any), '*']
    ]
  end

  def tag_cloud_tracker_operator_options
    [
      [l(:label_equals), '='],
      [l(:label_not_equals), '!'],
      [l(:label_has_been), 'ev'],
      [l(:label_has_never_been), '!ev'],
      [l(:label_changed_from), 'cf'],
      [l(:label_any), '*']
    ]
  end

  def tag_cloud_version_operator_options
    [
      [l(:label_equals), '='],
      [l(:label_not_equals), '!'],
      [l(:label_has_been), 'ev'],
      [l(:label_has_never_been), '!ev'],
      [l(:label_changed_from), 'cf'],
      [l(:label_none), '!*'],
      [l(:label_any), '*']
    ]
  end

  def tag_cloud_list_operator_options(with_none: false)
    with_none ? tag_cloud_version_operator_options : tag_cloud_tracker_operator_options
  end

  def tag_cloud_operator_label(operator)
    case operator.to_s
    when 'o' then l(:label_open_issues)
    when 'c' then l(:label_closed_issues)
    when '=' then l(:label_equals)
    when '!' then l(:label_not_equals)
    when '*' then l(:label_any)
    when '!=' then l(:label_none)
    when 'ev' then l(:label_has_been)
    when '!ev' then l(:label_has_never_been)
    when 'cf' then l(:label_changed_from)
    else l(:label_any)
    end
  end

  def tag_cloud_filters_summary(tag_cloud)
    return '' unless tag_cloud

    parts = []
    sop = tag_cloud.respond_to?(:normalized_status_operator) ? tag_cloud.normalized_status_operator : '*'
    vop = tag_cloud.respond_to?(:normalized_version_operator) ? tag_cloud.normalized_version_operator : '*'
    top = tag_cloud.respond_to?(:normalized_tracker_operator) ? tag_cloud.normalized_tracker_operator : '*'

    parts << operator_filter_summary(:field_status, sop, safe_names(IssueStatus, tag_cloud.status_filter))
    parts << operator_filter_summary(:field_fixed_version, vop, safe_names(Version, tag_cloud.version_filter))
    parts << operator_filter_summary(:field_tracker, top, safe_names(Tracker, tag_cloud.tracker_filter))

    if tag_cloud.tag_filter
      tag_names = if tag_cloud.tag_ids.any?
                    Redmineup::Tag.where(id: tag_cloud.tag_ids).order(:name).pluck(:name)
                  else
                    []
                  end
      parts << filter_summary(:tags, tag_names.presence || [l(:label_none)])
    end

    if tag_cloud.include_subprojects
      parts << content_tag(:span, l(:label_tag_cloud_show_in_subprojects, default: 'Show in subprojects'))
    end

    safe_join(parts, tag.br)
  end

  def tag_cloud_visibility_summary(tag_cloud)
    return '' unless tag_cloud

    case tag_cloud.visibility
    when 'owner'
      author_name = tag_cloud.visibility_author&.name
      if author_name.present?
        "#{l(:label_tag_cloud_visibility_owner)} (#{author_name})"
      else
        l(:label_tag_cloud_visibility_owner)
      end
    when 'roles'
      role_names = Role.where(id: tag_cloud.role_ids).order(:name).pluck(:name)
      if role_names.any?
        "#{l(:label_tag_cloud_visibility_roles)}: #{role_names.join(', ')}"
      else
        l(:label_tag_cloud_visibility_roles)
      end
    else
      l(:label_tag_cloud_visibility_all)
    end
  end

  def tag_cloud_letter_marker(kind)
    case kind.to_sym
    when :system
      content_tag(
        :span,
        l(:label_tag_cloud_badge_system),
        class: 'tag-cloud-marker tag-cloud-marker-system',
        title: l(:label_tag_cloud_badge_system_title)
      )
    when :inherited
      content_tag(
        :span,
        l(:label_tag_cloud_badge_inherited),
        class: 'tag-cloud-marker tag-cloud-marker-inherited',
        title: l(:label_tag_cloud_badge_inherited_title)
      )
    else
      ''.html_safe
    end
  end

  private

  def operator_filter_summary(label, operator, values)
    op_label = tag_cloud_operator_label(operator)
    text =
      if TagCloud::VALUE_OPERATORS.include?(operator.to_s)
        names = values.presence || ['—']
        "#{l(label)} #{op_label} #{names.join(', ')}"
      else
        "#{l(label)}: #{op_label}"
      end
    content_tag(:span, text)
  end

  def safe_names(model, ids)
    ids = Array(ids).map(&:to_i).reject(&:zero?)
    return [] if ids.empty?

    scope = model.where(id: ids)
    scope = scope.sorted if scope.respond_to?(:sorted)
    scope.pluck(:name)
  end

  def filter_summary(label, values)
    text =
      if values.blank?
        "#{l(label)}: #{l(:label_all)}"
      else
        "#{l(label)}: #{values.join(', ')}"
      end
    content_tag(:span, text)
  end

  def add_tags(style, tags, content, item_el, options)
    items = []
    tag_cloud tags, (1..8).to_a do |tag, weight|
      items << content_tag(item_el, render_issue_tag_link(tag, options),
                           class: "tag-nube-#{weight}",
                           style: (style == :simple_cloud ? 'font-size: 1em;' : ''))
    end
    separator = style == :simple_cloud ? tag_separator : ' '
    content << safe_join(items, separator)
  end
end
