class Attachment < ApplicationRecord
  include SoftDeletable
  has_paper_trail
  belongs_to :attachable
  belongs_to :user

  has_one_attached :file

  validates :file, presence: true

  # Helper method to get file name
  def filename
    file.filename.to_s if file.attached?
  end

  # Helper method to get file size in human readable format
  def file_size
    return nil unless file.attached?

    size = file.byte_size
    units = %w[B KB MB GB TB]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end
end
