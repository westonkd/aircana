# frozen_string_literal: true

require "spec_helper"
require "aircana/generators/agents_generator"

RSpec.describe Aircana::Generators::AgentsGenerator do
  describe ".available_default_agents" do
    it "returns list of available default agents" do
      expect(described_class.available_default_agents).to eq(%w[planner worker])
    end
  end

  describe ".create_default_agent" do
    let(:agent_name) { "planner" }
    let(:output_path) { "/tmp/test_output/agents/planner.md" }

    before do
      allow(Aircana.configuration).to receive(:claude_code_project_config_path).and_return("/tmp/test_output")
      allow(File).to receive(:write)
      allow(File).to receive(:read).and_return("template content")
    end

    it "creates default agent with correct parameters" do
      generator = instance_double(described_class)
      expect(described_class).to receive(:new).with(
        agent_name: agent_name,
        default_agent: true
      ).and_return(generator)
      expect(generator).to receive(:generate)

      described_class.create_default_agent(agent_name)
    end

    it "raises error for unknown default agent" do
      expect do
        described_class.create_default_agent("unknown")
      end.to raise_error(ArgumentError, "Unknown default agent: unknown")
    end
  end

  describe "#initialize" do
    context "with default_agent: true" do
      let(:generator) { described_class.new(agent_name: "planner", default_agent: true) }

      it "sets default_agent flag" do
        expect(generator.default_agent).to be true
      end

      it "allows nil values for description and model" do
        expect(generator.description).to be_nil
        expect(generator.model).to be_nil
      end
    end

    context "with default_agent: false" do
      let(:generator) do
        described_class.new(
          agent_name: "custom",
          short_description: "Test",
          description: "Test description",
          model: "sonnet",
          color: "blue",
          default_agent: false
        )
      end

      it "sets default_agent flag to false" do
        expect(generator.default_agent).to be false
      end

      it "sets all provided values" do
        expect(generator.agent_name).to eq("custom")
        expect(generator.short_description).to eq("Test")
        expect(generator.description).to eq("Test description")
        expect(generator.model).to eq("sonnet")
        expect(generator.color).to eq("blue")
      end
    end
  end

  describe "#default_template_path" do
    context "when default_agent is true" do
      let(:generator) { described_class.new(agent_name: "planner", default_agent: true) }

      it "returns path to default agent template" do
        expected_path = File.join(
          File.dirname(described_class.instance_method(:default_template_path).source_location[0]),
          "..", "templates", "agents", "defaults", "planner.erb"
        )
        expect(generator.send(:default_template_path)).to eq(expected_path)
      end
    end

    context "when default_agent is false" do
      let(:generator) do
        described_class.new(
          agent_name: "custom",
          short_description: "Test",
          description: "Test description",
          model: "sonnet",
          color: "blue",
          default_agent: false
        )
      end

      it "returns path to base agent template" do
        expected_path = File.join(
          File.dirname(described_class.instance_method(:default_template_path).source_location[0]),
          "..", "templates", "agents", "base_agent.erb"
        )
        expect(generator.send(:default_template_path)).to eq(expected_path)
      end
    end
  end
end
