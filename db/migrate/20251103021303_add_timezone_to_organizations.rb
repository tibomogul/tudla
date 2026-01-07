class AddTimezoneToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :timezone, :string, default: "Australia/Brisbane", null: false
    
    # Update existing organizations to use the default timezone
    reversible do |dir|
      dir.up do
        safety_assured do
          execute "UPDATE organizations SET timezone = 'Australia/Brisbane' WHERE timezone IS NULL"
        end
      end
    end
  end
end
