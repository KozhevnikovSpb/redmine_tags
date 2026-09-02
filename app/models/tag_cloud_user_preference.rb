# frozen_string_literal: true

# Per-user tag display (count vs weight) and master switch for untagged captions.
# Not cloud visibility. NULL columns mean inherit / default until the user saves My account.
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

    # Master switch from My account. Default off. Does not inherit plugin settings.
    def show_untagged?(user = User.current)
      return false unless user&.logged?
      return false unless table_available?
      return false unless column_names.include?('show_untagged')
      unless can_configure_untagged?(user)
        revoke_untagged_if_unauthorized!(user)
        return false
      end

      pref = stored_for(user)
      return false if pref.nil? || pref[:show_untagged].nil?

      ActiveModel::Type::Boolean.new.cast(pref[:show_untagged])
    rescue StandardError
      false
    end

    # Profile checkbox: select or manage tag clouds (or admin). view_tag_clouds is not enough.
    def can_configure_untagged?(user = User.current)
      return false unless user&.logged?
      return true if user.admin?

      %i[select_tag_clouds manage_tag_clouds].any? do |permission|
        user.allowed_to?(permission, nil, global: true)
      end
    rescue StandardError
      false
    end

    # Drop stored master + per-cloud untagged flags when the user no longer has management rights.
    def revoke_untagged_if_unauthorized!(user)
      return false unless user&.logged?
      return false if can_configure_untagged?(user)

      changed = false
      if table_available? && column_names.include?('show_untagged')
        rec = stored_for(user)
        if rec && !rec[:show_untagged].nil? && ActiveModel::Type::Boolean.new.cast(rec[:show_untagged])
          rec.show_untagged = false
          rec.save
          changed = true
        end
      end
      changed = true if TagCloudPreference.clear_untagged_for_user!(user)
      changed
    rescue StandardError => e
      Rails.logger.warn("[redmineup_tags] revoke_untagged: #{e.class}: #{e.message}") if defined?(Rails)
      false
    end

    def save_count_mode!(user, show_count)
      save_display!(user, show_count: show_count)
    end

    def save_display!(user, attrs = {})
      return false unless user&.logged?
      return false unless table_available?

      unless can_configure_untagged?(user)
        revoke_untagged_if_unauthorized!(user)
        attrs = attrs.except(:show_untagged)
      end

      rec = find_or_initialize_by(user_id: user.id)
      if attrs.key?(:show_count)
        rec.show_count = ActiveModel::Type::Boolean.new.cast(attrs[:show_count])
        rec.show_weight = !rec.show_count
      end
      if attrs.key?(:show_untagged) && column_names.include?('show_untagged') && can_configure_untagged?(user)
        rec.show_untagged = ActiveModel::Type::Boolean.new.cast(attrs[:show_untagged])
      end
      rec.save
    rescue StandardError => e
      Rails.logger.warn("[redmineup_tags] save_display: #{e.class}: #{e.message}") if defined?(Rails)
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
