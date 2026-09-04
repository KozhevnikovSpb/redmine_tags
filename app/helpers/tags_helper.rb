module TagsHelper
  include Redmineup::TagsHelper

  def tag_color_field(tag)
    stored = RedmineupTags.normalize_stored_color(tag.respond_to?(:color) ? tag.color : nil)
    auto = RedmineupTags.auto_tag_color(tag)
    muted_auto = RedmineupTags.mute_hex(auto)
    render partial: 'tags/color_editor', locals: {
      stored_hex: stored,
      auto_hex: auto,
      muted_auto_hex: muted_auto
    }
  end

  def render_issue_tag_link(tag, options = {})
    filters = issue_filters_for_tag_link(tag, options)

    content =
      if options[:use_search]
        link_to(tag, controller: 'search', action: 'index', id: @project, q: tag.name, wiki_pages: true, issues: true)
      else
        link_to_issue_filter(tag, filters)
      end
    content << content_tag('span', "(#{tag.count})", class: 'tag-count') if options[:show_count]
    style =
      if RedmineupTags.use_colors?
        bg = RedmineupTags.display_tag_color(tag)
        fg = RedmineupTags.tag_text_color(bg)
        { class: 'tag-label-color', style: "background-color: #{bg}; color: #{fg};" }
      else
        { class: 'tag-label' }
      end
    content_tag('span', content, style)
  end
