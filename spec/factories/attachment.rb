FactoryBot.define do
  factory :attachable do
    association :attachable, factory: :project
  end

  factory :attachment do
    association :attachable, factory: :attachable
    user

    file { Rack::Test::UploadedFile.new(StringIO.new("test content"), "image/png", true, original_filename: "test.png") }

    after(:build) do |attachment|
      attachment.file.attach(
        io: StringIO.new("test file content"),
        filename: "test.png",
        content_type: "image/png"
      ) unless attachment.file.attached?
    end

    trait :image do
      after(:build) do |attachment|
        attachment.file.attach(
          io: StringIO.new("fake image data"),
          filename: "photo.png",
          content_type: "image/png"
        )
      end
    end

    trait :pdf do
      after(:build) do |attachment|
        attachment.file.attach(
          io: StringIO.new("fake pdf data"),
          filename: "document.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :zip do
      after(:build) do |attachment|
        attachment.file.attach(
          io: StringIO.new("fake zip data"),
          filename: "archive.zip",
          content_type: "application/zip"
        )
      end
    end
  end
end
