require 'rails_helper'

RSpec.describe PaginatedListComponent, type: :component do
  include ViewComponent::TestHelpers
  include Capybara::RSpecMatchers

  let(:default_attrs) do
    {
      filter_url: "/dashboard",
      frame_id: "test_frame",
      filter_param: "q",
      filter_placeholder: "Search items...",
      title: "Test Title",
      current_filter: nil
    }
  end

  def render_component(**overrides, &block)
    attrs = default_attrs.merge(overrides)
    if block
      render_inline(described_class.new(**attrs), &block)
    else
      render_inline(described_class.new(**attrs)) { "<p>Content block</p>".html_safe }
    end
  end

  describe "rendering" do
    it "renders a card container" do
      render_component
      expect(page).to have_css("div.card")
    end

    it "renders a title heading when title is present" do
      render_component(title: "My Projects")
      expect(page).to have_css("h3", text: "My Projects")
    end

    it "does not render a title heading when title is nil" do
      render_component(title: nil)
      expect(page).not_to have_css("h3")
    end

    it "renders the yielded content block" do
      render_component { "Custom content".html_safe }
      expect(page).to have_text("Custom content")
    end
  end

  describe "filter input" do
    it "renders a text input with the given placeholder" do
      render_component(filter_placeholder: "Filter by name...")
      expect(page).to have_field(type: "text", placeholder: "Filter by name...")
    end

    it "populates the input with the current filter value" do
      render_component(current_filter: "Rails")
      expect(page).to have_field(type: "text", with: "Rails")
    end

    it "renders an empty input when no filter is active" do
      render_component(current_filter: nil)
      expect(page).to have_field(type: "text", with: "")
    end
  end

  describe "stimulus wiring" do
    before { render_component }

    it "attaches the list-filter stimulus controller to a wrapper element" do
      expect(page).to have_css('[data-controller="list-filter"]')
    end

    it "configures the controller with filter_url, filter_param, and frame_id values" do
      render_component(filter_url: "/search", filter_param: "name", frame_id: "results")
      controller_el = page.find('[data-controller="list-filter"]')
      expect(controller_el[:"data-list-filter-url-value"]).to eq("/search")
      expect(controller_el[:"data-list-filter-param-value"]).to eq("name")
      expect(controller_el[:"data-list-filter-frame-value"]).to eq("results")
    end

    it "wires the input to trigger filtering on input events" do
      input = page.find("input")
      expect(input[:"data-action"]).to include("list-filter#filter")
      expect(input[:"data-list-filter-target"]).to eq("input")
    end
  end

  describe "defaults" do
    it "uses 'paginated_list' as the default frame_id" do
      component = described_class.new(filter_url: "/test")
      expect(component.frame_id).to eq("paginated_list")
    end

    it "uses 'q' as the default filter_param" do
      component = described_class.new(filter_url: "/test")
      expect(component.filter_param).to eq("q")
    end

    it "uses 'Search...' as the default filter_placeholder" do
      component = described_class.new(filter_url: "/test")
      expect(component.filter_placeholder).to eq("Search...")
    end
  end
end
