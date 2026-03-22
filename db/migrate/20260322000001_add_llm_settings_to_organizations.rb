class AddLlmSettingsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :llm_api_key, :text
    add_column :organizations, :llm_api_base, :string
    add_column :organizations, :llm_model, :string
  end
end
