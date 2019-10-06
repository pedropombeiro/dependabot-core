# frozen_string_literal: true

require "dependabot/file_updaters"
require "dependabot/file_updaters/base"
require "dependabot/errors"
require "dependabot/common/file_updater_helper"

module Dependabot
  module Docker
    class FileUpdater < Dependabot::FileUpdaters::Base
      include Dependabot::Docker::FileUpdaterHelper

      FROM_REGEX = /FROM/i.freeze

      def self.updated_files_regex
        [/dockerfile/i]
      end

      def updated_dependency_files
        updated_files = []

        dependency_files.each do |file|
          next unless requirement_changed?(file, dependency)

          updated_files <<
            updated_file(
              file: file,
              content: updated_dockerfile_content(file)
            )
        end

        updated_files.reject! { |f| dependency_files.include?(f) }
        raise "No files changed!" if updated_files.none?

        updated_files
      end

      private

      def dependency
        # Dockerfiles will only ever be updating a single dependency
        dependencies.first
      end

      def check_required_files
        # Just check if there are any files at all.
        return if dependency_files.any?

        raise "No Dockerfile!"
      end

      def updated_dockerfile_content(file)
        updated_content =
          if specified_with_digest?(file)
            update_digest_and_tag(file)
          else
            update_tag(file)
          end

        raise "Expected content to change!" if updated_content == file.content

        updated_content
      end

      def digest_and_tag_regex(digest)
        /^#{FROM_REGEX}\s+.*@#{digest}/
      end

      def tag_regex(declaration)
        escaped_declaration = Regexp.escape(declaration)

        %r{^#{FROM_REGEX}\s+(docker\.io/)?#{escaped_declaration}(?=\s|$)}
      end
    end
  end
end

Dependabot::FileUpdaters.register("docker", Dependabot::Docker::FileUpdater)
