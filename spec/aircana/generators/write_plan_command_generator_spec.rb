# frozen_string_literal: true

require "spec_helper"
require "aircana/generators/write_plan_command_generator"

RSpec.describe Aircana::Generators::WritePlanCommandGenerator do
  describe "#generate" do
    let(:generator) { described_class.new(file_in: template_path, file_out: output_path) }
    let(:template_path) { "/tmp/test_template.erb" }
    let(:output_path) { "/tmp/test_output.md" }
    let(:template_content) { "Test template content" }

    before do
      allow(File).to receive(:read).with(template_path).and_return(template_content)
      allow(File).to receive(:write)
    end

    it "generates output file from template" do
      expect(File).to receive(:write).with(output_path, template_content)
      generator.generate
    end
  end

  describe "default paths" do
    let(:generator) { described_class.new }

    before do
      allow(Aircana.configuration).to receive(:output_dir).and_return("/tmp/output")
    end

    it "sets correct default template path" do
      expected_path = "/Users/wdransfield/GitHub/aircana/lib/aircana/generators/../templates/commands/write_plan.erb"
      expect(generator.send(:default_template_path)).to eq(expected_path)
    end

    it "sets correct default output path" do
      expect(generator.send(:default_output_path)).to eq("/tmp/output/commands/air-write-plan.md")
    end
  end
end
