# Links Implementation

## Overview
Implemented a delegated type pattern for managing external links that can be associated with Projects, Scopes, Tasks, Teams, and Organizations. Links have a URL and optional description.

## Database Schema

### Linkables Table
```ruby
create_table :linkables do |t|
  t.references :linkable, polymorphic: true, null: false
  t.timestamps
end
```

### Links Table
```ruby
create_table :links do |t|
  t.references :linkable, null: false, foreign_key: true
  t.string :url
  t.text :description
  t.references :user, null: false, foreign_key: true
  t.timestamps
end
```

## Models

### Linkable (Delegated Type)
- **Location**: `app/models/linkable.rb`
- **Pattern**: Delegated type with polymorphic association
- **Types**: Project, Scope, Task, Team, Organization
- **Associations**: 
  - `has_many :links, dependent: :destroy`

### Link
- **Location**: `app/models/link.rb`
- **Associations**:
  - `belongs_to :linkable`
  - `belongs_to :user`
- **Validations**: 
  - URL presence required
  - URL format validation (must be valid http/https URL)
- **Helper Methods**:
  - `domain` - Extracts domain from URL for display (e.g., "github.com")
- **Broadcasting**: After commit, broadcasts updates to the links list for real-time updates

### Model Updates
All five target models have been updated with:
```ruby
has_one :linkable, as: :linkable, dependent: :destroy
has_many :links, through: :linkable
```

## Controller

### LinksController
- **Location**: `app/controllers/links_controller.rb`
- **Actions**:
  - `create` - Create new link
  - `edit` - Show edit form
  - `update` - Update existing link
  - `destroy` - Delete link
- **Authorization**: Uses Pundit `LinkPolicy`
- **Features**:
  - Automatically creates Linkable record if needed
  - Associates link with current user
  - Redirects back to parent record after actions
  - Only link author can edit/delete their own links

## Policy

### LinkPolicy
- **Location**: `app/policies/link_policy.rb`
- **Permissions**: 
  - **Create**: User must have access to the parent record
  - **Update/Edit/Delete**: User must be the link author AND have access to parent record
- **Authorization Logic**:
  - Project: User must be project member, team member, or org member
  - Scope: Inherits project permissions
  - Task: Task assignee or project member
  - Team: Team member or org member
  - Organization: Org member
- **Implementation Note**: Uses string-based class name comparison (`linkable_record.class.name`) instead of `case/when` to avoid Rails class reloading issues in development mode

## Routes

```ruby
resources :links, only: [:create, :edit, :update, :destroy]
```

## UI Components

### Partials Created

1. **Link Form Modal** (`app/views/shared/_links_form.html.erb`)
   - DaisyUI modal dialog
   - URL field (required) with placeholder
   - Description textarea (optional)
   - Helper text for URL format
   - Cancel and Add Link buttons

2. **Links List** (`app/views/shared/_links_list.html.erb`)
   - Displays all links in compact card layout
   - Shows link icon and clickable URL
   - External link indicator (opens in new tab)
   - Domain extraction for quick reference
   - Description (if provided)
   - Author and timestamp
   - Edit/Delete buttons (only for link author)
   - Empty state message with icon
   - "(edited)" indicator if link was modified
   - Turbo stream target for real-time updates
   - Hover effects for better UX

3. **Edit View** (`app/views/links/edit.html.erb`)
   - Full-page edit form
   - URL and description fields
   - Update and Cancel buttons
   - Error handling display

4. **Section Wrapper** (`app/views/shared/_links_section.html.erb`)
   - Header with "New Link" button
   - Shows link count badge
   - Combines create modal and list
   - Requires `can_create` parameter (based on parent record's `update?` permission)
   - Auto-fetches linkable record if not provided

### Integration

Added to all show pages:
```erb
<%= render "shared/links_section", record: @project, can_create: policy(@project).update? %>
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
- Link icon for visual identification
- External link icon for clarity
- Responsive design with mobile support
- Consistent spacing and typography

### User Experience
- "New Link" button opens modal for creating links
- Link count displayed in header badge
- List shows most recent links first
- Clickable URLs open in new tab
- Domain shown for quick reference
- Description provides context
- Edit button only visible to link author
- Delete with confirmation dialog
- Empty state guides users to add first link
- Hover effects on cards for interactivity

### URL Handling
- URL field uses `url_field` input type for browser validation
- Format validation ensures http:// or https:// protocol
- Domain extraction for compact display
- External link icon indicates new tab behavior
- Full URL remains visible and accessible

## Security

- All actions require authentication
- Authorization through Pundit policies
- Inherits permissions from parent records
- Only link author can edit/delete their own links
- URL validated for proper format
- XSS protection via Rails sanitization

## Usage Examples

### Creating a Link
1. Navigate to any Project, Task, Scope, Team, or Organization show page
2. Click the "New Link" button (requires update permission on parent record)
3. Modal opens with create form
4. Enter URL (e.g., "https://github.com/user/repo")
5. Optionally add a description
6. Click "Add Link" button
7. Page updates and new link appears in list

### Editing a Link
1. Click the edit icon on your own link
2. Edit page opens with URL and description fields
3. Make changes and click "Update Link"
4. Redirected back to parent record

### Deleting a Link
- Click the delete icon (trash can) on your own link
- Confirm deletion in dialog
- Link is removed from list

## Known Issues & Solutions

### Rails Class Reloading in Development
The LinkPolicy uses string-based class name comparison to avoid issues with Rails class reloading in development mode. See `docs/attachment_policy_fix.md` for similar pattern explanation.

**Symptom**: Policy returns `false` even when user has proper permissions.  
**Solution**: Use `linkable_record.class.name` instead of `case/when` with class objects.

## Future Enhancements

Potential improvements:
- Link preview/unfurling (show page title, favicon, description)
- Link categories/tags
- Link validation (check if URL is accessible)
- Bulk link import
- Link grouping by domain
- Link search/filter
- Link click tracking
- Archive/inactive links
- Link shortening
- Automatic screenshot capture
