namespace :pulse do
  desc "Backfill missing Pulse::Subscribable rows for existing projects, scopes and tasks"
  task backfill_subscribables: :environment do
    Pulse.config.subscribable_types.each do |type|
      klass = type.constantize
      created = 0
      klass.where.missing(:subscribable).find_each do |record|
        Pulse::Subscribable.create_or_find_by!(subscribable: record)
        created += 1
      end
      puts "#{type}: created #{created} subscribable rows."
    end
    puts "Backfill complete."
  end
end
