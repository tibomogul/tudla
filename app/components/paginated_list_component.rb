# frozen_string_literal: true

class PaginatedListComponent < ViewComponent::Base
  attr_reader :filter_url, :frame_id, :filter_param, :filter_placeholder, :title, :current_filter

  def initialize(filter_url:, frame_id: "paginated_list", filter_param: "q", filter_placeholder: "Search...", title: nil, current_filter: nil)
    @filter_url = filter_url
    @frame_id = frame_id
    @filter_param = filter_param
    @filter_placeholder = filter_placeholder
    @title = title
    @current_filter = current_filter
  end
end
