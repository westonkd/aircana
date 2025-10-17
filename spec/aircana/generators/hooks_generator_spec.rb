# frozen_string_literal: true

require "spec_helper"
require "aircana/generators/hooks_generator"

RSpec.describe Aircana::Generators::HooksGenerator do
  describe ".available_default_hooks" do
    it "returns list of available default hooks" do
      expected_hooks = %w[
        session_start
        notification_sqs
      ]
      expect(described_class.available_default_hooks).to eq(expected_hooks)
    end
  end

  describe ".all_available_hooks" do
    it "returns list of all available hooks" do
      expected_hooks = %w[
        pre_tool_use
        post_tool_use
        user_prompt_submit
        session_start
        notification_sqs
        rubocop_pre_commit
        rspec_test
        bundle_install
      ]
      expect(described_class.all_available_hooks).to eq(expected_hooks)
    end
  end

  describe ".create_default_hook" do
    let(:hook_name) { "pre_tool_use" }
    let(:scripts_dir) { "/tmp/test_hooks" }
    let(:expected_template_path) do
      base_path = File.dirname(described_class.instance_method(:initialize).source_location[0])
      File.join(base_path, "..", "templates", "hooks", "#{hook_name}.erb")
    end
    let(:expected_output_path) { File.join(scripts_dir, "#{hook_name}.sh") }

    before do
      allow(Aircana.configuration).to receive(:scripts_dir).and_return(scripts_dir)
      allow(File).to receive(:read).and_return("#!/bin/bash\necho 'test hook'")
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:chmod)
    end

    it "creates hook with correct parameters" do
      generator = instance_double(described_class)
      expect(described_class).to receive(:new).with(
        file_in: expected_template_path,
        file_out: expected_output_path
      ).and_return(generator)
      expect(generator).to receive(:generate).and_return(expected_output_path)

      result = described_class.create_default_hook(hook_name)
      expect(result).to eq(expected_output_path)
    end

    it "returns nil for unknown hook" do
      result = described_class.create_default_hook("unknown_hook")
      expect(result).to be_nil
    end
  end

  describe ".create_all_default_hooks" do
    it "creates all default hooks" do
      expect(described_class).to receive(:create_default_hook).exactly(2).times
      described_class.create_all_default_hooks
    end
  end

  describe "#initialize" do
    context "with hook_name provided" do
      let(:hook_name) { "pre_tool_use" }
      let(:scripts_dir) { "/tmp/test_hooks" }

      before do
        allow(Aircana.configuration).to receive(:scripts_dir).and_return(scripts_dir)
      end

      it "sets up template and output paths correctly" do
        generator = described_class.new(hook_name: hook_name)

        base_path = File.dirname(described_class.instance_method(:initialize).source_location[0])
        expected_template_path = File.join(base_path, "..", "templates", "hooks", "#{hook_name}.erb")
        expected_output_path = File.join(scripts_dir, "#{hook_name}.sh")

        expect(generator.file_in).to eq(expected_template_path)
        expect(generator.file_out).to eq(expected_output_path)
      end
    end

    context "with custom file paths" do
      let(:custom_in) { "/custom/template.erb" }
      let(:custom_out) { "/custom/output.sh" }

      it "uses provided file paths" do
        generator = described_class.new(file_in: custom_in, file_out: custom_out)

        expect(generator.file_in).to eq(custom_in)
        expect(generator.file_out).to eq(custom_out)
      end
    end
  end

  describe "#generate" do
    let(:hook_name) { "pre_tool_use" }
    let(:scripts_dir) { "/tmp/test_hooks" }
    let(:output_path) { File.join(scripts_dir, "#{hook_name}.sh") }

    before do
      allow(Aircana.configuration).to receive(:scripts_dir).and_return(scripts_dir)
      allow(File).to receive(:read).and_return("#!/bin/bash\necho '<%= hook_name %>'")
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
      allow(File).to receive(:exist?).with(output_path).and_return(true)
      allow(File).to receive(:chmod)
    end

    it "generates hook script and makes it executable" do
      generator = described_class.new(hook_name: hook_name)

      expect(File).to receive(:write).with(output_path, anything)
      expect(File).to receive(:chmod).with(0o755, output_path)

      result = generator.generate
      expect(result).to eq(output_path)
    end
  end

  describe "#locals" do
    let(:hook_name) { "pre_tool_use" }
    let(:current_dir) { "/current/project" }

    before do
      allow(Aircana.configuration).to receive(:scripts_dir).and_return("/tmp/hooks")
      allow(Dir).to receive(:pwd).and_return(current_dir)
    end

    it "includes hook-specific variables" do
      generator = described_class.new(hook_name: hook_name)
      locals = generator.send(:locals)

      expect(locals[:hook_name]).to eq(hook_name)
      expect(locals[:project_root]).to eq(current_dir)
      expect(locals).to have_key(:helpers)
    end
  end
end
