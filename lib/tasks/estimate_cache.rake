namespace :estimate_cache do
  desc "Backfill cached estimate columns on scopes and projects"
  task backfill: :environment do
    puts "Backfilling scope estimate caches..."
    Scope.find_each do |scope|
      Task.recalculate_estimates_for(scope)
    end
    puts "  Done. Updated #{Scope.count} scopes."

    puts "Backfilling project estimate caches..."
    Project.find_each do |project|
      Task.recalculate_estimates_for(project)
    end
    puts "  Done. Updated #{Project.count} projects."

    puts "Backfill complete."
  end
end
