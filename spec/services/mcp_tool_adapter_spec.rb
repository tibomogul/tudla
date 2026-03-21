# frozen_string_literal: true

require "rails_helper"

RSpec.describe McpToolAdapter do
  describe ".tool_method_name" do
    it "converts ListTasksTool to :list_tasks" do
      expect(described_class.tool_method_name(ListTasksTool)).to eq(:list_tasks)
    end

    it "converts TransitionTaskStateTool to :transition_task_state" do
      expect(described_class.tool_method_name(TransitionTaskStateTool)).to eq(:transition_task_state)
    end

    it "converts GetProjectTool to :get_project" do
      expect(described_class.tool_method_name(GetProjectTool)).to eq(:get_project)
    end
  end

  describe ".register_mcp_tools!" do
    before { described_class.register_mcp_tools! }

    it "registers a LangChain function for every MCP tool" do
      schemas = described_class.function_schemas.to_anthropic_format

      expect(schemas.size).to be >= 19
    end

    it "generates valid Anthropic-format schemas" do
      schemas = described_class.function_schemas.to_anthropic_format

      schemas.each do |schema|
        expect(schema).to have_key(:name)
        expect(schema).to have_key(:description)
        expect(schema).to have_key(:input_schema)
        expect(schema[:input_schema]).to have_key(:type)
        expect(schema[:input_schema][:type]).to eq("object")
      end
    end

    it "uses correct function names with tool_name prefix" do
      schemas = described_class.function_schemas.to_anthropic_format
      names = schemas.map { |s| s[:name] }

      expect(names).to include("mcp_tool_adapter__list_tasks")
      expect(names).to include("mcp_tool_adapter__get_task")
      expect(names).to include("mcp_tool_adapter__create_task")
    end

    it "preserves MCP tool descriptions" do
      schemas = described_class.function_schemas.to_anthropic_format
      list_tasks_schema = schemas.find { |s| s[:name] == "mcp_tool_adapter__list_tasks" }

      expect(list_tasks_schema[:description]).to eq(ListTasksTool.description_value)
    end

    it "preserves required fields from MCP schema" do
      schemas = described_class.function_schemas.to_anthropic_format
      transition_schema = schemas.find { |s| s[:name] == "mcp_tool_adapter__transition_task_state" }

      required = transition_schema[:input_schema][:required]
      expect(required).to include("task_id")
      expect(required).to include("state")
    end

    it "preserves property types from MCP schema" do
      schemas = described_class.function_schemas.to_anthropic_format
      list_tasks_schema = schemas.find { |s| s[:name] == "mcp_tool_adapter__list_tasks" }

      properties = list_tasks_schema[:input_schema][:properties]
      expect(properties[:project_id][:type]).to eq("integer")
      expect(properties[:state][:type]).to eq("string")
      expect(properties[:in_today][:type]).to eq("boolean")
    end

    it "is safe to call multiple times (reload safety)" do
      described_class.register_mcp_tools!
      described_class.register_mcp_tools!

      schemas = described_class.function_schemas.to_anthropic_format
      expect(schemas.size).to be >= 19
    end
  end

  describe "tool execution" do
    let(:organization) { create(:organization, name: "Test Org") }
    let(:team) { create(:team, name: "Test Team", organization: organization) }
    let(:user) do
      create(:user, email: "adapter@example.com", username: "adapteruser", confirmation_token: "token_mta1").tap do |u|
        UserPartyRole.create!(user: u, party: organization, role: "member")
      end
    end
    let(:adapter) { described_class.new(user: user) }
    let(:project) { create(:project, name: "Adapter Test Project", team: team) }

    before { described_class.register_mcp_tools! }

    it "delegates to MCP tool execute and returns ToolResponse" do
      project # ensure exists

      result = adapter.list_projects

      expect(result).to be_a(Langchain::ToolResponse)
      expect(result.content).to include("project(s)")
    end

    it "passes server_context with user to MCP tool" do
      expect(adapter.server_context).to eq({ user: user })
    end

    it "handles authorization errors gracefully" do
      # Org member can see tasks (via scope) but cannot update (requires team/project membership or org admin)
      viewer_user = create(:user, email: "viewer@example.com", username: "vieweruser", confirmation_token: "token_mta2").tap do |u|
        UserPartyRole.create!(user: u, party: organization, role: "member")
      end
      viewer_adapter = described_class.new(user: viewer_user)

      task = create(:task, project: project, name: "Secret Task")

      result = viewer_adapter.update_task(task_id: task.id, name: "Hacked")

      expect(result).to be_a(Langchain::ToolResponse)
      expect(result.content).to include("Authorization error:")
    end

    it "handles domain errors gracefully" do
      result = adapter.get_task(task_id: -999)

      expect(result).to be_a(Langchain::ToolResponse)
      expect(result.content).to include("Error:")
    end
  end
end
