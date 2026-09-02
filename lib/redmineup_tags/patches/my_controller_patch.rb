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

        attrs = {}
        attrs[:show_count] = params.dig(:tag_display, :show_count) if params[:tag_display].key?(:show_count)
        if params[:tag_display].key?(:show_untagged) && TagCloudUserPreference.can_configure_untagged?(User.current)
          attrs[:show_untagged] = params.dig(:tag_display, :show_untagged)
        end
        TagCloudUserPreference.save_display!(User.current, attrs) if attrs.any?
      rescue StandardError => e
        Rails.logger.warn("[redmineup_tags] my account tag display: #{e.class}: #{e.message}")
      end
    end
  end
end

unless MyController.included_modules.include?(RedmineupTags::Patches::MyControllerPatch)
  MyController.prepend RedmineupTags::Patches::MyControllerPatch
end
