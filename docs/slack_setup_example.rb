# Example script to configure Slack delivery for report requirements
# Run this in Rails console: rails console

# Example 1: Configure Slack webhook for a specific report requirement
report_requirement = ReportRequirement.find(1) # Replace with your report requirement ID

report_requirement.update!(
  delivery: {
    slack: {
      enabled: true,
      webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
      channel: "#weekly-reports" # Optional, defaults to webhook's channel
    }
  }
)

puts "✅ Configured Slack webhook for Report Requirement ##{report_requirement.id}"

# Example 2: Configure Slack API token for a report requirement
report_requirement = ReportRequirement.find(2) # Replace with your report requirement ID

report_requirement.update!(
  delivery: {
    slack: {
      enabled: true,
      token: ENV.fetch("SLACK_BOT_TOKEN"), # Better to use environment variable
      channel: "#project-updates"
    }
  }
)

puts "✅ Configured Slack API token for Report Requirement ##{report_requirement.id}"

# Example 3: Disable Slack posting
report_requirement = ReportRequirement.find(3)

report_requirement.update!(
  delivery: {
    slack: {
      enabled: false
    }
  }
)

puts "✅ Disabled Slack posting for Report Requirement ##{report_requirement.id}"

# Example 4: Configure multiple report requirements at once
project = Project.find_by(name: "Alpha Project")
reportable = Reportable.find_by(reportable: project)

if reportable
  report_requirements = ReportRequirement.where(reportable: reportable)
  
  report_requirements.each do |rr|
    rr.update!(
      delivery: {
        slack: {
          enabled: true,
          webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
          channel: "#alpha-project-reports"
        }
      }
    )
  end
  
  puts "✅ Configured Slack for #{report_requirements.count} report requirements"
else
  puts "❌ Reportable not found for project '#{project.name}'"
end

# Example 5: Test posting a report manually
report = Report.last

# Check if Slack is configured
report_requirement = ReportRequirement.find_by(reportable_id: report.reportable_id)
slack_service = SlackService.new(report, report_requirement)

if slack_service.slack_configured?
  puts "✅ Slack is configured"
  
  # Test post (this will actually post to Slack!)
  begin
    SlackService.post_report(report, report_requirement)
    puts "✅ Successfully posted to Slack!"
  rescue SlackService::SlackPostError => e
    puts "❌ Failed to post to Slack: #{e.message}"
  end
else
  puts "❌ Slack is not configured for this report requirement"
end

# Example 6: View current delivery configuration
report_requirement = ReportRequirement.find(1)
puts "\n📋 Current delivery configuration for Report Requirement ##{report_requirement.id}:"
puts JSON.pretty_generate(report_requirement.delivery)

# Example 7: Check scheduled Slack posts
scheduled_jobs = SolidQueue::Job.where(queue_name: "default")
                                 .where("arguments LIKE ?", "%PostReportToSlackJob%")
                                 .scheduled

puts "\n📅 Scheduled Slack post jobs: #{scheduled_jobs.count}"
scheduled_jobs.each do |job|
  puts "  - Job ##{job.id}, scheduled for: #{job.scheduled_at}"
end
