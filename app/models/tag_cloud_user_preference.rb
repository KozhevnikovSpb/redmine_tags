# frozen_string_literal: true

# Per-user display options for tag clouds.
# Independent from TagCloudPreference (sidebar visibility / order).
# NULL columns mean "inherit plugin settings".
class TagCloudUserPreference < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  class << self
    def for_user(user)
      return nil unless user&.logged?

      find_or_initialize_by(user_id: user.id)
    end

    def show_count?(user = User.current)
      inherited = RedmineupTags.settings['issues_show_count'].to_i == 1
      pref = stored_for(user)
      return inherited if pref.nil? || pref.show_count.nil?

      pref.show_count
    end

    def show_weight?(user = User.current)
      inherited = RedmineupTags.tag_list_view == :cloud
      pref = stored_for(user)
      return inherited if pref.nil? || pref.show_weight.nil?

      pref.show_weight
    end

    def stored_for(user)
      return nil unless user&.logged?
      return nil unless table_available?

      find_by(user_id: user.id)
    rescue StandardError
      nil
    end

    def table_available?
      table_exists?
    rescue StandardError
      false
    end
  end
end
