module Pulse
  # Default fan-out visibility gate: re-checks Pundit show? for each
  # recipient. Access-revocation safety — never notify a user who can no
  # longer see the underlying subject; errors count as "not visible".
  #
  # This is O(recipients) policy instantiations. Host apps can replace it via
  # config.visibility_filter with a batched implementation that knows their
  # authorization hierarchy (see PulseVisibilityFilter).
  class VisibilityFilter
    def call(subject, recipients)
      recipients.select { |recipient| visible_to?(recipient, subject) }
    end

    private

    def visible_to?(recipient, subject)
      Pundit.policy!(recipient, subject).show?
    rescue StandardError => e
      Rails.logger.error("[Pulse::VisibilityFilter] Visibility check failed for user ##{recipient.id} " \
                         "on #{subject.class.name}##{subject.id}: #{e.class}: #{e.message}")
      false
    end
  end
end
