# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Aircana::CLI::DoctorChecks::AircanaConfiguration do
  subject(:checker) { checker_class.new }

  let(:checker_class) do
    Class.new do
      include Aircana::CLI::DoctorChecks::AircanaConfiguration

      attr_reader :successes, :infos, :remedies

      def initialize
        @successes = []
        @infos = []
        @remedies = []
      end

      def log_success(label, message)
        @successes << [label, message]
      end

      def log_info(label, message)
        @infos << [label, message]
      end

      def log_remedy(message)
        @remedies << message
      end
    end
  end

  around do |example|
    Dir.mktmpdir do |temp_dir|
      original_skills_dir = Aircana.configuration.skills_dir
      @skills_dir = File.join(temp_dir, "skills")
      Aircana.configuration.skills_dir = @skills_dir

      example.run

      Aircana.configuration.skills_dir = original_skills_dir
    end
  end

  describe "#check_knowledge_bases_status" do
    it "counts knowledge bases from SKILL.md files under the skills directory" do
      %w[backend-api database-design].each do |kb|
        FileUtils.mkdir_p(File.join(@skills_dir, kb))
        File.write(File.join(@skills_dir, kb, "SKILL.md"), "---\nname: Learn\n---\n")
      end

      checker.check_knowledge_bases_status

      expect(checker.successes).to include(["KBs", "2 knowledge base(s) configured"])
    end

    it "ignores skill directories without a SKILL.md" do
      FileUtils.mkdir_p(File.join(@skills_dir, "half-built"))

      checker.check_knowledge_bases_status

      expect(checker.infos).to include(["KBs", "Knowledge bases directory exists but is empty"])
    end

    it "reports no knowledge bases when the skills directory is absent" do
      checker.check_knowledge_bases_status

      expect(checker.infos).to include(["KBs", "No knowledge bases configured yet"])
      expect(checker.remedies).to include("Create knowledge bases with: aircana kb create")
    end
  end
end
