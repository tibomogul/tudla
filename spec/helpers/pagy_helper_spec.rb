require 'rails_helper'
require 'ostruct'

RSpec.describe PagyHelper, type: :helper do
  # Build a Pagy::Offset instance for testing.
  # Pagy v43 requires a request object for URL composition; we stub url_for
  # in the helper to avoid needing a full request context.
  def build_pagy(count:, page: 1, limit: 10)
    request = OpenStruct.new(GET: {}, path: "/dashboard")
    Pagy::Offset.new(count: count, page: page, limit: limit, request: request)
  end

  # Parse HTML string into a Capybara node for matcher support
  def parsed(html)
    Capybara.string(html)
  end

  before do
    # Stub request.query_parameters so pagy_page_url can merge existing params
    allow(helper.request).to receive(:query_parameters).and_return({})

    # Stub url_for so the helper can generate pagination links without full routing
    allow(helper).to receive(:url_for) do |*args|
      opts = args.last.is_a?(Hash) ? args.last : (args.first.is_a?(Hash) ? args.first : {})
      params = opts.map { |k, v| "#{k}=#{v}" }.join("&")
      "/dashboard?#{params}"
    end
  end

  describe "#pagy_daisyui_nav" do
    context "when there is only one page" do
      it "returns an empty string" do
        pagy = build_pagy(count: 5)
        result = helper.pagy_daisyui_nav(pagy)
        expect(result).to eq("")
      end
    end

    context "when there are multiple pages" do
      let(:pagy) { build_pagy(count: 50, page: 2) }

      it "renders a DaisyUI join container" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("div.join")
      end

      it "renders page number buttons as join-items" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css(".join-item.btn.btn-sm", minimum: 3)
      end

      it "marks the current page as btn-active" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("span.btn-active", text: "2")
      end

      it "renders the current page as a span (not a link)" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("span.btn-active", text: "2")
        expect(doc).not_to have_css("a.btn-active")
      end

      it "renders other pages as links" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("a.join-item", text: "1")
        expect(doc).to have_css("a.join-item", text: "3")
      end

      it "renders previous button as a link when not on first page" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("a.join-item", text: "«")
      end

      it "renders next button as a link when not on last page" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("a.join-item", text: "»")
      end
    end

    context "when on the first page" do
      let(:pagy) { build_pagy(count: 30, page: 1) }

      it "disables the previous button" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("span.btn-disabled", text: "«")
      end

      it "enables the next button as a link" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("a.join-item", text: "»")
      end
    end

    context "when on the last page" do
      let(:pagy) { build_pagy(count: 30, page: 3) }

      it "enables the previous button as a link" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("a.join-item", text: "«")
      end

      it "disables the next button" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("span.btn-disabled", text: "»")
      end
    end

    context "with turbo_frame option" do
      let(:pagy) { build_pagy(count: 30, page: 1) }

      it "adds data-turbo-frame attribute to page links" do
        doc = parsed(helper.pagy_daisyui_nav(pagy, turbo_frame: "my_frame"))
        expect(doc).to have_css('a[data-turbo-frame="my_frame"]')
      end

      it "does not add data-turbo-frame to disabled span buttons" do
        doc = parsed(helper.pagy_daisyui_nav(pagy, turbo_frame: "my_frame"))
        expect(doc).to have_css("span.btn-disabled", text: "«")
        expect(doc).not_to have_css('span.btn-disabled[data-turbo-frame]')
      end
    end

    context "url_for param merging" do
      let(:pagy) { build_pagy(count: 30, page: 2) }

      it "passes page param to url_for for each page link but not for the current page" do
        received_params = []
        allow(helper).to receive(:url_for) do |*args|
          opts = args.last.is_a?(Hash) ? args.last : (args.first.is_a?(Hash) ? args.first : {})
          received_params << opts
          "/dashboard?page=#{opts[:page]}"
        end

        helper.pagy_daisyui_nav(pagy)
        pages_requested = received_params.map { |p| p[:page] }
        # Should include pages for: previous(1), page 1, page 3, next(3)
        # Page 2 is current and rendered as a span (no url_for call)
        expect(pages_requested).to include(1, 3)
        expect(pages_requested).not_to include(2)
      end

      it "preserves existing query params (e.g. filters) in pagination links" do
        # Override the before block's empty query_parameters stub
        allow(helper.request).to receive(:query_parameters)
          .and_return({ "project_name" => "Rails" })

        # Capture url_for calls to verify merged params
        url_for_calls = []
        allow(helper).to receive(:url_for) do |*args, **kwargs|
          opts = {}
          args.each { |a| opts.merge!(a) if a.is_a?(Hash) }
          opts.merge!(kwargs)
          url_for_calls << opts.dup
          query = opts.map { |k, v| "#{k}=#{v}" }.join("&")
          "/dashboard?#{query}"
        end

        helper.pagy_daisyui_nav(pagy)

        # Filter out empty url_for calls from Rails link_to internals;
        # only assert on the pagy_page_url calls that carry params
        page_url_calls = url_for_calls.reject(&:empty?)
        expect(page_url_calls).not_to be_empty
        expect(page_url_calls).to all(include("project_name" => "Rails"))
        expect(page_url_calls).to all(include(page: a_value > 0))
      end
    end

    context "with many pages (gap/ellipsis)" do
      let(:pagy) { build_pagy(count: 200, page: 10) }

      it "renders ellipsis gaps for distant pages" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css("span.btn-disabled", text: "…")
      end

      it "always shows the first page" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css(".join-item", text: "1")
      end

      it "always shows the last page" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css(".join-item", text: "20")
      end

      it "shows pages around the current page" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        expect(doc).to have_css(".join-item", text: "9")
        expect(doc).to have_css("span.btn-active", text: "10")
        expect(doc).to have_css(".join-item", text: "11")
      end
    end

    context "with few pages (no gap needed)" do
      let(:pagy) { build_pagy(count: 50, page: 3) }

      it "shows all page numbers without ellipsis" do
        doc = parsed(helper.pagy_daisyui_nav(pagy))
        (1..5).each do |p|
          expect(doc).to have_css(".join-item", text: p.to_s)
        end
        expect(doc).not_to have_css(".btn-disabled", text: "…")
      end
    end
  end
end
