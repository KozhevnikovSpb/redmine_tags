# frozen_string_literal: true

# Per-user tag display (count vs weight). Not cloud visibility.
# NULL columns mean inherit plugin settings until the user saves My account.
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
      !show_count?(user)
    end

    def save_count_mode!(user, show_count)
      return false unless user&.logged?
      return false unless table_available?

      rec = find_or_initialize_by(user_id: user.id)
      rec.show_count = ActiveModel::Type::Boolean.new.cast(show_count)
      rec.show_weight = !rec.show_count
      rec.save
    rescue StandardError => e
      Rails.logger.warn("[redmineup_tags] save_count_mode: #{e.class}: #{e.message}") if defined?(Rails)
      false
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
