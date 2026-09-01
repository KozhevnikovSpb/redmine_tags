# frozen_string_literal: true

module RedmineupTags
  module Patches
    module MyControllerPatch
      def self.prepended(base)
        base.class_eval do
          after_action :save_tag_display_preference, only: :account
        end
      end

      private

      def save_tag_display_preference
        return unless request.put?
        return unless User.current.logged?
        return unless params.key?(:tag_display)
        return unless response.redirect? || performed?

        show_count = params.dig(:tag_display, :show_count)
        TagCloudUserPreference.save_count_mode!(User.current, show_count)
      rescue StandardError => e
        Rails.logger.warn("[redmineup_tags] my account tag display: #{e.class}: #{e.message}")
      end
    end
  end
end

unless MyController.included_modules.include?(RedmineupTags::Patches::MyControllerPatch)
  MyController.prepend RedmineupTags::Patches::MyControllerPatch
end
