# Slack Integration for Reports

## Overview

The task management system can automatically post submitted reports to Slack based on configuration stored in the `report_requirement.delivery` JSON field.

## Features

- **Automatic Posting**: Reports are automatically posted to Slack when submitted
- **Smart Scheduling**: 
  - Reports submitted **after** the `as_of_date` are posted **immediately**
  - Reports submitted **before** the `as_of_date` are scheduled to post **on** the `as_of_date`
- **Optional Configuration**: If Slack configuration is not present in the delivery JSON, no posting occurs
- **Dual Methods**: Supports both Slack Webhooks and Slack API tokens

## Configuration

### Report Requirement Delivery JSON Structure

The `delivery` field in `report_requirements` table should be a JSON object with the following structure:

```json
{
  "slack": {
    "enabled": true,
    "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "channel": "#reports"
  }
}
```

Or using Slack API token:

```json
{
  "slack": {
    "enabled": true,
    "token": "xoxb-your-slack-bot-token",
    "channel": "#reports"
  }
}
```

### Configuration Fields

- **`enabled`** (boolean, required): Must be `true` to enable Slack posting
- **`webhook_url`** (string, optional): Slack incoming webhook URL
- **`token`** (string, optional): Slack bot token (starts with `xoxb-`)
- **`channel`** (string, optional): Target Slack channel (defaults to `#general`)

**Note**: You must provide either `webhook_url` OR `token`, not both.

## Setup

### Method 1: Using Slack Webhooks (Recommended)

1. Go to your Slack workspace settings
2. Navigate to Apps → Incoming Webhooks
3. Create a new webhook for your desired channel
4. Copy the webhook URL
5. Add the webhook URL to your report requirement's delivery JSON

**Pros**:
- Simple to set up
- No OAuth required
- Works without additional bot permissions

**Cons**:
- Limited to posting messages only
- Can only post to the channel specified in the webhook

### Method 2: Using Slack API Token

1. Create a Slack App in your workspace
2. Add the following OAuth scopes under "Bot Token Scopes":
   - `chat:write`
   - `chat:write.public` (if posting to public channels)
3. Install the app to your workspace
4. Copy the Bot User OAuth Token (starts with `xoxb-`)
5. Add the token to your report requirement's delivery JSON

**Pros**:
- Can post to any channel
- More flexible for future enhancements

**Cons**:
- Requires app installation and permission management
- More complex setup

## Message Format

Reports posted to Slack include:

- **Header**: Report title with the reportable entity name (e.g., "📊 Project Alpha Report")
- **Metadata**: Submitted by (user's preferred name) and report date
- **Content**: Full report content in markdown format
- **Formatting**: Uses Slack blocks for better visual presentation

### Example Message

```
📊 Project Alpha Report

Submitted by: John Doe
As of: October 30, 2025

─────────────────

[Report content here]
```

## Database Schema

### report_requirements table

```ruby
t.jsonb :delivery, default: {}, null: false
```

The `delivery` field stores configuration as JSONB, allowing flexible schema for different delivery methods (Slack, email, etc.).

## Implementation Details

### Components

1. **SlackService** (`app/services/slack_service.rb`)
   - Handles Slack API interactions
   - Supports both webhook and API token methods
   - Formats messages with blocks for rich display

2. **PostReportToSlackJob** (`app/jobs/post_report_to_slack_job.rb`)
   - Background job using Solid Queue
   - Handles asynchronous posting
   - Includes error handling and logging

3. **ReportsController** (`app/controllers/reports_controller.rb`)
   - Triggers Slack posting on report submission
   - Schedules immediate or delayed posting based on timing

### Timing Logic

```ruby
if report.submitted_at >= report.as_of_at
  # Post immediately
  PostReportToSlackJob.perform_later(report.id)
else
  # Schedule for as_of_date
  PostReportToSlackJob.set(wait_until: report.as_of_at).perform_later(report.id)
end
```

### Error Handling

- **No Configuration**: Job silently skips if Slack is not configured
- **API Errors**: Logged and re-raised for Solid Queue retry mechanism
- **Network Errors**: Logged and re-raised for retry
- **Missing Reports**: Logged but not re-raised

## Testing

### Testing in Development

1. Create a test Slack workspace or channel
2. Generate a webhook URL or bot token
3. Add configuration to a report requirement:

```ruby
report_requirement = ReportRequirement.first
report_requirement.update(
  delivery: {
    slack: {
      enabled: true,
      webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
      channel: "#test-reports"
    }
  }
)
```

4. Submit a report and check Slack

### Manual Job Execution

```ruby
# In Rails console
report = Report.last
PostReportToSlackJob.perform_now(report.id)
```

## Troubleshooting

### Report Not Posted to Slack

1. Check if `delivery.slack.enabled` is `true`
2. Verify webhook URL or token is valid
3. Check Rails logs for errors: `[PostReportToSlackJob]` or `[SlackService]`
4. Verify Solid Queue is running: `docker compose logs rails`

### Permission Errors

- Ensure Slack bot has `chat:write` permission
- Ensure bot is invited to the target channel
- For webhooks, verify the webhook is still active

### Job Not Executing

- Check Solid Queue status
- Verify `as_of_at` date is correct
- Check scheduled jobs: `SolidQueue::Job.scheduled`

## Security Considerations

- **Never commit webhook URLs or tokens** to version control
- Store tokens in environment variables or encrypted credentials for production
- Rotate webhook URLs/tokens periodically
- Use least-privilege permissions for Slack bots
- The current implementation stores tokens in the database JSONB field - consider using Rails encrypted attributes for sensitive tokens in production

## Future Enhancements

Possible improvements to consider:

- [ ] Support for Slack threads (posting follow-up comments)
- [ ] Support for @mentions in reports
- [ ] Rich formatting with Slack Block Kit
- [ ] Attachments and file uploads
- [ ] Multiple channel destinations
- [ ] Slack reactions for report approval workflow
- [ ] Integration with Slack slash commands
- [ ] Encrypted storage for Slack tokens
