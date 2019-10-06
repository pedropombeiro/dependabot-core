# frozen_string_literal: true

require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/common/file_parser_helper"

module Dependabot
  module Docker
    class FileParser < Dependabot::FileParsers::Base
      require "dependabot/file_parsers/base/dependency_set"

      include Dependabot::Docker::FileParserHelper

      # Details of Docker regular expressions is at
      # https://github.com/docker/distribution/blob/master/reference/regexp.go
      DOMAIN_COMPONENT =
        /(?:[[:alnum:]]|[[:alnum:]][[[:alnum:]]-]*[[:alnum:]])/.freeze
      DOMAIN = /(?:#{DOMAIN_COMPONENT}(?:\.#{DOMAIN_COMPONENT})+)/.freeze
      REGISTRY = /(?<registry>#{DOMAIN}(?::\d+)?)/.freeze

      NAME_COMPONENT = /(?:[a-z\d]+(?:(?:[._]|__|[-]*)[a-z\d]+)*)/.freeze
      IMAGE = %r{(?<image>#{NAME_COMPONENT}(?:/#{NAME_COMPONENT})*)}.freeze

      FROM = /FROM/i.freeze
      TAG = /:(?<tag>[\w][\w.-]{0,127})/.freeze
      DIGEST = /@(?<digest>[^\s]+)/.freeze
      NAME = /\s+AS\s+(?<name>[\w-]+)/.freeze
      FROM_LINE =
        %r{^#{FROM}\s+(#{REGISTRY}/)?#{IMAGE}#{TAG}?#{DIGEST}?#{NAME}?}.freeze

      AWS_ECR_URL = /dkr\.ecr\.(?<region>[^.]+).amazonaws\.com/.freeze

      def parse
        dependency_set = DependencySet.new

        dockerfiles.each do |dockerfile|
          dockerfile.content.each_line do |line|
            next unless FROM_LINE.match?(line)

            parsed_from_line = FROM_LINE.match(line).named_captures
            if parsed_from_line["registry"] == "docker.io"
              parsed_from_line["registry"] = nil
            end

            version = version_from(parsed_from_line)
            next unless version

            dependency_set << Dependency.new(
              name: parsed_from_line.fetch("image"),
              version: version,
              package_manager: "docker",
              requirements: [
                requirement: nil,
                groups: [],
                file: dockerfile.name,
                source: source_from(parsed_from_line)
              ]
            )
          end
        end

        dependency_set.dependencies
      end

      private

      def dockerfiles
        # The Docker file fetcher only fetches Dockerfiles, so no need to
        # filter here
        dependency_files
      end

      def check_required_files
        # Just check if there are any files at all.
        return if dependency_files.any?

        raise "No Dockerfile!"
      end
    end
  end
end

Dependabot::FileParsers.register("docker", Dependabot::Docker::FileParser)
