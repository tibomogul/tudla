# Attachments Implementation

## Overview
Implemented a delegated type pattern for file attachments that can be associated with Projects, Scopes, Tasks, Teams, and Organizations using Active Storage.

## Database Schema

### Attachables Table
```ruby
create_table :attachables do |t|
  t.references :attachable, polymorphic: true, null: false
  t.timestamps
end
```

### Attachments Table
```ruby
create_table :attachments do |t|
  t.references :attachable, null: false, foreign_key: true
  t.text :description
  t.references :user, null: false, foreign_key: true
  t.timestamps
end
```

## Models

### Attachable (Delegated Type)
- **Location**: `app/models/attachable.rb`
- **Pattern**: Delegated type with polymorphic association
- **Types**: Project, Scope, Task, Team, Organization
- **Associations**: 
  - `has_many :attachments, dependent: :destroy`

### Attachment
- **Location**: `app/models/attachment.rb`
- **Associations**:
  - `belongs_to :attachable`
  - `belongs_to :user`
  - `has_one_attached :file` (Active Storage)
- **Validations**: 
  - File presence required
- **Helper Methods**:
  - `filename` - Returns the uploaded file's name
  - `file_size` - Returns human-readable file size (e.g., "2.5 MB")

### Model Updates
All five target models have been updated with:
```ruby
has_one :attachable, as: :attachable, dependent: :destroy
has_many :attachments, through: :attachable
```

## Controller

### AttachmentsController
- **Location**: `app/controllers/attachments_controller.rb`
- **Actions**:
  - `create` - Upload new attachment
  - `destroy` - Delete attachment
  - `download` - Download attachment file
- **Authorization**: Uses Pundit `AttachmentPolicy`
- **Features**:
  - Automatically creates Attachable record if needed
  - Associates attachment with current user
  - Redirects back to parent record after actions

## Policy

### AttachmentPolicy
- **Location**: `app/policies/attachment_policy.rb`
- **Permissions**: Based on user's access to the parent record
- **Authorization Logic**:
  - Project: User must be project member, team member, or org member
  - Scope: Inherits project permissions
  - Task: Task assignee or project member
  - Team: Team member or org member
  - Organization: Org member
- **Implementation Note**: Uses string-based class name comparison (`attachable_record.class.name`) instead of `case/when` to avoid Rails class reloading issues in development mode

## Routes

```ruby
resources :attachments, only: [:create, :destroy] do
  member do
    get :download
  end
end
```

## UI Components

### Partials Created

1. **Upload Modal** (`app/views/shared/_attachments_upload.html.erb`)
   - DaisyUI modal dialog
   - File input field
   - Optional description textarea
   - Cancel and Upload buttons
   - Maximum file size: 100MB

2. **Attachments List** (`app/views/shared/_attachments_list.html.erb`)
   - Displays all attachments in cards
   - Shows filename, size, uploader, and timestamp
   - Download button
   - Delete button (permission-based)
   - Empty state message

3. **Section Wrapper** (`app/views/shared/_attachments_section.html.erb`)
   - Header with "New Attachment" button
   - Shows attachment count badge
   - Combines upload modal and list
   - Requires `can_upload` parameter (based on parent record's `update?` permission)
   - Auto-fetches attachable record if not provided

### Integration

Added to all show pages:
```erb
<%= render "shared/attachments_section", record: @project, can_upload: policy(@project).update? %>
```

**Pages Updated**:
- `app/views/projects/show.html.erb`
- `app/views/tasks/show.html.erb`
- `app/views/scopes/show.html.erb`
- `app/views/teams/show.html.erb`
- `app/views/organizations/show.html.erb`

## UI Patterns

### Design Consistency
- Follows established DaisyUI component patterns
- Uses Heroicons for SVG icons
- Card-based layout matching existing UI
- Responsive design with mobile support
- Consistent spacing and typography

### User Experience
- "New Attachment" button opens modal for uploads
- Attachment count displayed in header badge
- List shows most recent attachments first
- File metadata clearly displayed
- One-click download
- Confirmation dialog for deletion
- Empty state guides users to upload

## Active Storage

Files are stored using Active Storage with:
- Blob storage in `active_storage_blobs` table
- Attachment records in `active_storage_attachments` table
- CDN-ready with signed URLs
- Support for all file types

## Security

- All actions require authentication
- Authorization through Pundit policies
- Inherits permissions from parent records
- File uploads validated
- Signed URLs for downloads

## Usage Examples

### Uploading an Attachment
1. Navigate to any Project, Task, Scope, Team, or Organization show page
2. Click the "New Attachment" button (requires update permission on parent record)
3. Modal opens with upload form
4. Select file and optionally add description
5. Click "Upload" button
6. Page refreshes and new attachment appears in list

### Downloading an Attachment
- Click the download icon on any attachment card

### Deleting an Attachment
- Click the delete icon (trash can) if authorized
- Confirm deletion in dialog

## Testing

To verify the implementation:
```bash
# Check model associations
docker compose exec rails bash -lc "bin/rails runner 'puts Project.reflect_on_all_associations.select { |a| a.name.to_s.include?(\"attach\") }.map(&:name).inspect'"

# Check routes
docker compose exec rails bash -lc "bin/rails routes | grep attachment"

# Verify Attachable model
docker compose exec rails bash -lc "bin/rails runner 'puts Attachable.reflect_on_all_associations.map(&:name).inspect'"
```

## Known Issues & Solutions

### Rails Class Reloading in Development
The AttachmentPolicy uses string-based class name comparison to avoid issues with Rails class reloading in development mode. See `docs/attachment_policy_fix.md` for details.

**Symptom**: Policy returns `false` even when user has proper permissions.  
**Solution**: Use `attachable_record.class.name` instead of `case/when` with class objects.

## Future Enhancements

Potential improvements:
- Image preview for image files
- File type icons based on extension
- Bulk upload support
- Attachment versioning
- Search/filter attachments
- Attachment sharing links
