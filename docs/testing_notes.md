# Testing Notes Feature

## Manual Testing Steps

### 1. Navigate to a Show Page
Visit any of the following:
- Project show page: `/projects/:id`
- Task show page: `/tasks/:id`
- Scope show page: `/scopes/:id`
- Team show page: `/teams/:id`
- Organization show page: `/organizations/:id`

### 2. Look for the Notes Section
At the bottom of the page (after Attachments), you should see:
- **Section Header**: "Notes" with a count badge
- **"New Note" button**: Primary blue button with a plus icon (if you have permission)
- **Empty State**: "No notes yet. Add your first note to get started." (if no notes exist)

### 3. Click "New Note" Button
- A modal dialog should open with the title "New Note"
- The modal contains:
  - Title field (optional)
  - Marksmith editor (required) with split-pane interface
    - Left pane: markdown editing with toolbar
    - Right pane: live preview of rendered content
  - "Cancel" button (closes modal)
  - "Create Note" button (primary blue, with plus icon)

### 4. Create a Note
1. Optionally add a title
2. Write content using markdown syntax in the Marksmith editor
3. See live preview in the right pane as you type
4. Use toolbar buttons for common formatting (bold, italic, lists, etc.)
5. Click "Create Note"
6. Page should refresh
7. Modal should close
8. New note should appear in the list with rendered markdown

### 5. Verify Note Display
Each note card should show:
- Title (if provided)
- Author name with user icon
- Time created (e.g., "5 minutes ago")
- "(edited)" indicator if modified
- Rendered markdown content with proper formatting
- Edit button (pencil icon, only for your own notes)
- Delete button (trash icon, only for your own notes)

### 6. Test Markdown Rendering
Create notes with various markdown syntax:
- **Bold text**: `**bold**`
- *Italic text*: `*italic*`
- Headings: `# H1`, `## H2`, etc.
- Lists: `- item` or `1. item`
- Links: `[text](url)`
- Code: `` `code` `` or ``` for blocks

### 7. Edit a Note
- Click the edit (pencil) icon on your own note
- Edit page should open
- See title field
- Marksmith editor with split-pane interface for content
- Additional rendered preview section below editor
- Make changes and see live preview as you type
- Click "Update Note"
- Should redirect back to parent record
- Changes should be reflected in the note

### 8. Delete a Note
- Click the delete (trash) icon on your own note
- Confirm deletion in dialog
- Page should refresh
- Note should be removed from the list

## Expected Behavior

### Permissions
- **Create**: Only users with `update?` permission on the parent record can create notes
- **Edit**: Only the note author can edit their own notes
- **Delete**: Only the note author can delete their own notes
- **View**: All users with access to the parent record can view notes
- **Button Visibility**: "New Note" button shows only if user has update permission

### Access Rules
- **Project**: Project member, team member, or organization member
- **Task**: Task assignee or project member
- **Scope**: Inherits project permissions
- **Team**: Team member or organization member
- **Organization**: Organization member

## Console Testing

```ruby
# Test Project notes
project = Project.first
notable = project.notable || Notable.create!(notable: project)
note = notable.notes.create!(
  user: User.first,
  title: "Test Note",
  content: "# Heading\n\nThis is a **test** note with *markdown*."
)

# Verify
project.reload
project.notes.count # Should be > 0
project.notes.first.title # Should show "Test Note"
project.notes.first.content # Should show markdown content

# Test markdown rendering
note.content = "# Hello World\n\n**Bold** and *italic* text."
note.save
helper = Object.new.extend(ApplicationHelper)
puts helper.render_markdown(note.content) # Should show HTML with proper formatting

# Test Task notes
task = Task.first
notable = task.notable || Notable.create!(notable: task)
# ... same as above
```

## Troubleshooting

### "New Note" button not showing
- Verify you're logged in
- Verify you have `update?` permission on the parent record (Project, Task, Scope, Team, or Organization)
- Check browser console for JavaScript errors
- For development mode issues, see `docs/attachment_policy_fix.md` (same pattern applies)

### Note creation fails
- Verify content is not empty (required field)
- Check Rails logs for errors
- Verify Notable record is created correctly

### Markdown not rendering
- Verify Commonmarker gem is installed
- Check for HTML sanitization issues
- Verify content is being passed to `render_markdown` helper
- Check that ApplicationHelper is included

### Edit/Delete buttons not showing
- Verify you are the author of the note
- Only the note author can edit/delete their own notes
- Check that current_user matches note.user

### Notes not appearing after creation
- Verify the redirect is working
- Check if Turbo is enabled
- Look for errors in Rails logs
- Verify Notable association is correct

## Rails Console Verification

```bash
# Check routes
docker compose exec rails bash -lc "bin/rails routes | grep note"

# Check associations
docker compose exec rails bash -lc "bin/rails runner 'puts Project.reflect_on_all_associations.select { |a| a.name.to_s.include?(\"note\") }.map(&:name).inspect'"

# Check Notable model
docker compose exec rails bash -lc "bin/rails runner 'puts Notable.reflect_on_all_associations.map(&:name).inspect'"

# Test markdown rendering
docker compose exec rails bash -lc "bin/rails runner 'note = Note.first; helper = Object.new.extend(ApplicationHelper); puts helper.render_markdown(note.content)'"
```

## Testing Checklist

- [ ] Create note on Project
- [ ] Create note on Task
- [ ] Create note on Scope
- [ ] Create note on Team
- [ ] Create note on Organization
- [ ] Marksmith editor shows split-pane with live preview
- [ ] Toolbar buttons work (bold, italic, links, etc.)
- [ ] Edit own note
- [ ] Delete own note
- [ ] Cannot edit others' notes
- [ ] Cannot delete others' notes
- [ ] Markdown renders correctly (headings, bold, italic, lists)
- [ ] Code blocks render with proper formatting
- [ ] Emoji shortcodes work (e.g., `:smile:`)
- [ ] Empty state shows when no notes exist
- [ ] Note count badge updates correctly
- [ ] "(edited)" indicator appears after editing
- [ ] Permissions work correctly for all record types
