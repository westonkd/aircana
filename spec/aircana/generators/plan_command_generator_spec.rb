# frozen_string_literal: true

require "spec_helper"
require "aircana/generators/plan_command_generator"

RSpec.describe Aircana::Generators::PlanCommandGenerator do
  describe "#generate" do
    let(:output_path) { "/tmp/test_output/commands/air-plan.md" }
    let(:generator) { described_class.new(file_out: output_path) }

    before do
      allow(Aircana.configuration).to receive(:output_dir).and_return("/tmp/test_output")
      allow(File).to receive(:write)
      allow(FileUtils).to receive(:mkdir_p)
    end

    it "generates the plan command file" do
      expect(File).to receive(:write).with(output_path, anything)
      generator.generate
    end

    it "returns the output file path" do
      allow(File).to receive(:write)
      result = generator.generate
      expect(result).to eq(output_path)
    end

    it "creates the output directory" do
      expect(FileUtils).to receive(:mkdir_p).with("/tmp/test_output/commands")
      generator.generate
    end
  end

  describe "default paths" do
    let(:generator) { described_class.new }

    before do
      allow(Aircana.configuration).to receive(:output_dir).and_return("/test/output")
    end

    it "uses the correct template path" do
      expected_path = File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "aircana", "templates", "commands",
                                "plan.erb")
      actual_path = generator.send(:file_in)
      expect(File.expand_path(actual_path)).to eq(File.expand_path(expected_path))
    end

    it "uses the correct output path" do
      expected_path = "/test/output/commands/air-plan.md"
      expect(generator.send(:file_out)).to eq(expected_path)
    end
  end
end
