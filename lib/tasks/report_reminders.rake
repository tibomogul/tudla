namespace :report_reminders do
  desc "Schedule reminder jobs for all active report requirements"
  task schedule: :environment do
    puts "Scheduling report requirement reminders..."
    puts "See Rails logs for detailed information"
    puts ""
    
    stats = ReportRequirementReminderScheduler.call
    
    puts ""
    puts "Results:"
    puts "  Scheduled: #{stats[:scheduled]}"
    puts "  Skipped: #{stats[:skipped]}"
    puts "  Errors: #{stats[:errors]}"
    puts ""
    puts "Done! Check logs/#{Rails.env}.log for details"
  end
end
