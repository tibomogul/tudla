# rake task to remove all active storage files
# Usage: bin/rails active_storage:remove_all
namespace :active_storage do
  desc "Remove all active storage files"
  task remove_all: :environment do
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
    FileUtils.mkdir_p(ActiveStorage::Blob.service.root)
  end
end
