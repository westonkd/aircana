# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.global_dir).to eq(File.join(Dir.home, ".aircana"))
      expect(config.project_dir).to eq(Dir.pwd)
      expect(config.stream).to eq($stdout)
      expect(config.output_dir).to eq(File.join(Dir.home, ".aircana", "aircana.out"))
    end
  end

  describe "#relevant_project_files_dir" do
    it "returns the .aircana/relevant_files directory within project_dir" do
      expected_path = File.join(config.project_dir, ".aircana", "relevant_files")
      expect(config.relevant_project_files_dir).to eq(expected_path)
    end
  end
end
