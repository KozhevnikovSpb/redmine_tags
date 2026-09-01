# frozen_string_literal: true

module RedmineupTags
  module Hooks
    class ViewsMyAccountHook < Redmine::Hook::ViewListener
      render_on :view_my_account_preferences, partial: 'my/tag_display_preferences'
    end
  end
end
