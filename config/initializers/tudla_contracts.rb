# Reset integrations registry on every prepare cycle
# integrations use an after load_config_initilizers prepare block to register
Rails.configuration.to_prepare do
  Rails.logger.info "Resetting integrations registry"
  TudlaContracts::Integrations::Registry.reset!
end
