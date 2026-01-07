# Notes Implementation

## Overview
Implemented a delegated type pattern for markdown notes that can be associated with Projects, Scopes, Tasks, Teams, and Organizations. Notes support full markdown formatting rendered with Commonmarker via the `render_markdown` helper.

## Database Schema

### Notables Table
```ruby
create_table :notables do |t|
  t.references :notable, polymorphic: true, null: false
  t.timestamps
end
```

### Notes Table
```ruby
create_table :notes do |t|
  t.references :notable, null: false, foreign_key: true
  t.string :title
  t.text :content
  t.references :user, null: false, foreign_key: true
  t.timestamps
end
```

## Models

### Notable (Delegated Type)
- **Location**: `app/models/notable.rb`
- **Pattern**: Delegated type with polymorphic association
- **Types**: Project, Scope, Task, Team, Organization
- **Associations**: 
  - `has_many :notes, dependent: :destroy`

### Note
- **Location**: `app/models/note.rb`
- **Associations**:
  - `belongs_to :notable`
  - `belongs_to :user`
- **Validations**: 
  - Content presence required
- **Broadcasting**: After commit, broadcasts updates to the notes list for real-time updates
- **Rendering**: Markdown content is rendered in views using the `render_markdown` helper from ApplicationHelper

### Model Updates
All five target models have been updated with:
```ruby
has_one :notable, as: :notable, dependent: :destroy
has_many :notes, through: :notable
```

## Controller

### NotesController
- **Location**: `app/controllers/notes_controller.rb`
- **Actions**:
  - `create` - Create new note
  - `edit` - Show edit form
  - `update` - Update existing note
  - `destroy` - Delete note
- **Authorization**: Uses Pundit `NotePolicy`
- **Features**:
  - Automatically creates Notable record if needed
  - Associates note with current user
  - Redirects back to parent record after actions
  - Only note author can edit/delete their own notes

## Policy

### NotePolicy
- **Location**: `app/policies/note_policy.rb`
- **Permissions**: 
  - **Create**: User must have access to the parent record
  - **Update/Edit/Delete**: User must be the note author AND have access to parent record
- **Authorization Logic**:
  - Project: User must be project member, team member, or org member
  - Scope: Inherits project permissions
  - Task: Task assignee or project member
  - Team: Team member or org member
  - Organization: Org member
- **Implementation Note**: Uses string-based class name comparison (`notable_record.class.name`) instead of `case/when` to avoid Rails class reloading issues in development mode

## Routes

```ruby
resources :notes, only: [:create, :edit, :update, :destroy]
```

## UI Components

### Partials Created

1. **Note Form Modal** (`app/views/shared/_notes_form.html.erb`)
   - DaisyUI modal dialog
   - Title field (optional)
   - Marksmith editor for markdown content with live preview
   - Split-pane interface: edit on left, preview on right
   - Toolbar with formatting buttons
   - Cancel and Create buttons

2. **Notes List** (`app/views/shared/_notes_list.html.erb`)
   - Displays all notes in card layout
   - Shows title (if provided), author, timestamp
   - Renders markdown content as HTML with prose styling
   - Edit/Delete buttons (only for note author)
   - Empty state message with icon
   - "(edited)" indicator if note was modified
   - Turbo stream target for real-time updates

3. **Edit View** (`app/views/notes/edit.html.erb`)
   - Full-page edit form
   - Title field
   - Marksmith editor for content with live preview
   - Additional rendered preview section below editor
   - Update and Cancel buttons
   - Error handling display

4. **Section Wrapper** (`app/views/shared/_notes_section.html.erb`)
   - Header with "New Note" button
   - Shows note count badge
   - Combines create modal and list
   - Requires `can_create` parameter (based on parent record's `update?` permission)
   - Auto-fetches notable record if not provided

### Integration

Added to all show pages:
```erb
<%= render "shared/notes_section", record: @project, can_create: policy(@project).update? %>
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
- Prose styling for rendered markdown
- Responsive design with mobile support
- Consistent spacing and typography

### User Experience
- "New Note" button opens modal for creating notes
- Note count displayed in header badge
- Marksmith editor provides split-pane interface with live preview
- Toolbar with common markdown formatting shortcuts
- List shows most recent notes first
- Markdown content rendered with proper typography
- Edit button only visible to note author
- Delete with confirmation dialog
- Empty state guides users to create first note
- "(edited)" indicator for transparency

### Markdown Support
- **Editor**: Marksmith WYSIWYG markdown editor with live preview
- **Rendering**: Commonmarker gem for HTML output
- GitHub Flavored Markdown (GFM) with extensions:
  - Strikethrough, tables, autolinks, task lists
  - Emoji shortcodes (`:emoji:`)
- Code blocks with syntax highlighting (InspiredGitHub theme)
- Smart punctuation and hard line breaks
- XSS protection (unsafe HTML disabled)
- Prose styling via `ms:prose` classes with dark mode support
- Theme-aware rendering with `theme-dark` controller
- Split-pane interface: edit markdown on left, see preview on right
- Toolbar with formatting shortcuts (bold, italic, links, lists, etc.)

## Security

- All actions require authentication
- Authorization through Pundit policies
- Inherits permissions from parent records
- Only note author can edit/delete their own notes
- Content validated for presence
- XSS protection via HTML sanitization in Commonmarker (unsafe: false)

## Usage Examples

### Creating a Note
1. Navigate to any Project, Task, Scope, Team, or Organization show page
2. Click the "New Note" button (requires update permission on parent record)
3. Modal opens with create form
4. Optionally add a title
5. Write content in markdown format
6. Click "Create Note" button
7. Page updates and new note appears in list

### Editing a Note
1. Click the edit icon on your own note
2. Edit page opens with title and content fields
3. See live preview of rendered markdown below
4. Make changes and click "Update Note"
5. Redirected back to parent record

### Deleting a Note
- Click the delete icon (trash can) on your own note
- Confirm deletion in dialog
- Note is removed from list

## Known Issues & Solutions

### Rails Class Reloading in Development
The NotePolicy uses string-based class name comparison to avoid issues with Rails class reloading in development mode. See `docs/attachment_policy_fix.md` for similar pattern explanation.

**Symptom**: Policy returns `false` even when user has proper permissions.  
**Solution**: Use `notable_record.class.name` instead of `case/when` with class objects.

## Future Enhancements

Potential improvements:
- Note templates
- Tagging/categorization system
- Search/filter notes
- Export notes to PDF/markdown file
- Note versioning/history
- @mentions in notes
- Attachments to notes
- Pin important notes to top
