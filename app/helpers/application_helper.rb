module ApplicationHelper
  def flash_class_for(type)
    case type.to_sym
    when :notice
      "alert-info"
    when :success
      "alert-success"
    when :error, :alert
      "alert-error"
    else
      "alert-info"
    end
  end

  def render_markdown(text)
    # Return an empty string if the input is nil to prevent errors.
    return "" if text.nil?

    # Define parse options. :SMART enables smart punctuation (e.g., curly quotes).
    parse_options = {
      parse: {
        smart: true
      }
    }

    # Define render options.
    # :HARDBREAKS converts newlines to <br> tags.
    # :UNSAFE is set to false to prevent rendering raw HTML and protect against XSS attacks.
    render_options = {
      render: {
        hardbreaks: true,
        unsafe: false # This is the default, but explicitly set for security clarity.
      }
    }

    # Define GFM extensions to enable.
    # Most are enabled by default, but being explicit is good practice.
    # :shortcodes is crucial for Slack-style :emoji: support.
    extension_options = {
      extension: {
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true,
        shortcodes: true # Enables emoji shortcodes
      }
    }

    # Define plugins. The syntax_highlighter plugin provides server-side code highlighting.
    # We choose a built-in theme here.
    plugin_options = {
      plugins: {
        syntax_highlighter: {
          theme: "InspiredGitHub"
        }
      }
    }

    # Combine all options into a single hash.
    options = parse_options.deep_merge(render_options)
                          .deep_merge(extension_options)

    # Render the Markdown to HTML with the specified options and plugins.
    # The output is marked as.html_safe because we have sanitized it through CommonMarker.
    rendered_html = Commonmarker.to_html(text, options: options, plugins: plugin_options)
    content_tag(:div, data: { controller: "theme-dark" }) do
      content_tag(:div, rendered_html.html_safe, class: "marksmith-rendered-body ms:prose ms:prose-neutral ms:dark:prose-invert")
    end
  end

  def display_name_with_nice_to_have(record)
    prefix = record.nice_to_have ? "~ " : ""
    "#{prefix}#{record.name}"
  end

  def render_markdown_inline(text)
    # Simplified markdown rendering for inline content without wrapper divs
    return "<p></p>".html_safe if text.nil? || text.blank?

    parse_options = {
      parse: {
        smart: true
      }
    }

    render_options = {
      render: {
        hardbreaks: true,
        unsafe: false
      }
    }

    extension_options = {
      extension: {
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true,
        shortcodes: true
      }
    }

    plugin_options = {
      plugins: {
        syntax_highlighter: {
          theme: "InspiredGitHub"
        }
      }
    }

    options = parse_options.deep_merge(render_options)
                          .deep_merge(extension_options)

    result = Commonmarker.to_html(text, options: options, plugins: plugin_options)
    # Ensure we always return something truthy for JavaScript data attributes
    rendered = result&.html_safe || "<p></p>".html_safe
    rendered.presence || "<p></p>".html_safe
  rescue StandardError => e
    Rails.logger.error("Error rendering markdown: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    "<p class='text-error'>Error rendering content</p>".html_safe
  end

  def truncate_markdown_at_newline(text, word_limit)
    # Truncate text at last newline before word limit
    return "" if text.nil? || text.blank?

    words = text.split(/\s+/)
    return text if words.length <= word_limit

    # Find character position of word limit
    word_count = 0
    char_position = 0

    text.chars.each_with_index do |char, i|
      if char.match?(/\s/) && i > 0 && !text[i - 1].match?(/\s/)
        word_count += 1
        if word_count >= word_limit
          char_position = i
          break
        end
      end
    end

    # If we didn't find enough words, just return the whole text
    return text if char_position == 0

    # Find last newline before word limit
    text_up_to_limit = text[0...char_position]
    last_newline_index = text_up_to_limit.rindex("\n")

    truncated = if last_newline_index && last_newline_index > 0
      # Truncate at last newline
      text[0...last_newline_index] + "\n\n..."
    else
      # No newline found, truncate at word limit
      words[0...word_limit].join(" ") + "..."
    end

    # Ensure we never return blank truncated content
    truncated.presence || text
  end
end
