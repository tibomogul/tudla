# Pulse — event subscription & notification pipeline.
#
# Three pillars:
#   Producer      — Pulse::Publishable / Pulse::Publisher create Pulse::Event rows
#                   inside the domain transaction (transactional outbox).
#   Orchestration — Pulse::FanoutJob resolves recipients and hands them to channels.
#   Notification  — Pulse::Channels::* deliver (in-app = Pulse::Notification rows).
#
# Host-app coupling lives in config/initializers/pulse.rb; core code must not
# reference app models (Project, UserPartyRole, ...) directly so the namespace
# can later be extracted into a gem/engine.
module Pulse
  # Tables (subscribables, subscriptions, events, notifications) predate the
  # namespace and stay unprefixed. An extracted engine would make this configurable.
  def self.table_name_prefix
    ""
  end

  Config = Struct.new(:subscribable_types, :channels, :recipient_resolver, :catalog_extensions,
                      :visibility_filter)

  def self.config
    @config ||= Config.new([], [ "Pulse::Channels::InApp" ], nil, [])
  end

  def self.configure
    yield config
  end

  # Channel classes are configured as strings and constantized lazily so code
  # reloading in development doesn't hold stale class references.
  def self.channels
    config.channels.map(&:constantize)
  end

  def self.recipient_resolver
    case (resolver = config.recipient_resolver)
    when String then resolver.constantize.new
    when nil then Pulse::RecipientResolver.new
    else resolver
    end
  end

  def self.visibility_filter
    case (filter = config.visibility_filter)
    when String then filter.constantize.new
    when nil then Pulse::VisibilityFilter.new
    else filter
    end
  end
end
