# frozen_string_literal: true

module PagyHelper
  def pagy_daisyui_nav(pagy, turbo_frame: nil)
    return "".html_safe unless pagy.pages > 1

    link_data = turbo_frame ? { turbo_frame: turbo_frame } : {}

    tags = []

    # Previous button
    if pagy.previous
      tags << link_to(raw("&laquo;"), pagy_page_url(pagy.previous), class: "join-item btn btn-sm", data: link_data)
    else
      tags << content_tag(:span, raw("&laquo;"), class: "join-item btn btn-sm btn-disabled")
    end

    # Page numbers with ellipsis for large page counts
    pagy_page_items(pagy).each do |item|
      case item
      when Integer
        if item == pagy.page
          tags << content_tag(:span, item, class: "join-item btn btn-sm btn-active")
        else
          tags << link_to(item, pagy_page_url(item), class: "join-item btn btn-sm", data: link_data)
        end
      when :gap
        tags << content_tag(:span, "…", class: "join-item btn btn-sm btn-disabled")
      end
    end

    # Next button
    if pagy.next
      tags << link_to(raw("&raquo;"), pagy_page_url(pagy.next), class: "join-item btn btn-sm", data: link_data)
    else
      tags << content_tag(:span, raw("&raquo;"), class: "join-item btn btn-sm btn-disabled")
    end

    content_tag(:div, safe_join(tags), class: "join")
  end

  private

  # Build a URL for the given page, preserving existing query params (e.g. filters).
  # This ensures pagination links don't lose the current filter state.
  def pagy_page_url(page)
    url_for(request.query_parameters.merge(page: page))
  end

  def pagy_page_items(pagy)
    pages = pagy.pages
    page  = pagy.page

    # Show all pages if 7 or fewer
    return (1..pages).to_a if pages <= 7

    items = []
    items << 1

    if page > 3
      items << :gap
    end

    # Pages around current
    ([ page - 1, 2 ].max..[ page + 1, pages - 1 ].min).each do |p|
      items << p
    end

    if page < pages - 2
      items << :gap
    end

    items << pages
    items.uniq
  end
end
