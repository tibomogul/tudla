# Testing Attachments Feature

## Manual Testing Steps

### 1. Navigate to a Show Page
Visit any of the following:
- Project show page: `/projects/:id`
- Task show page: `/tasks/:id`
- Scope show page: `/scopes/:id`
- Team show page: `/teams/:id`
- Organization show page: `/organizations/:id`

### 2. Look for the Attachments Section
At the bottom of the page, you should see:
- **Section Header**: "Attachments" with a count badge
- **"New Attachment" button**: Primary blue button with a plus icon (if you have permission)
- **Empty State**: "No attachments yet. Upload files to get started." (if no attachments exist)

### 3. Click "New Attachment" Button
- A modal dialog should open with the title "Upload Attachment"
- The modal contains:
  - File input field
  - Description textarea (optional)
  - "Cancel" button (closes modal)
  - "Upload" button (primary blue, with upload icon)

### 4. Upload a File
1. Click "Choose File" button
2. Select a file from your computer
3. Optionally add a description
4. Click "Upload"
5. Page should refresh and show success notice
6. Modal should close
7. New attachment should appear in the list

### 5. Verify Attachment List
Each attachment card should show:
- File icon
- Filename
- File size (e.g., "2.5 MB")
- Uploader name
- Time uploaded (e.g., "5 minutes ago")
- Description (if provided)
- Download button (download icon)
- Delete button (trash icon, only if you have permission)

### 6. Download an Attachment
- Click the download icon
- File should download to your computer

### 7. Delete an Attachment (if permitted)
- Click the delete (trash) icon
- Confirm deletion in the dialog
- Page should refresh
- Attachment should be removed from the list

## Expected Behavior

### Permissions
- **Upload**: Only users with `update?` permission on the parent record can upload
- **Download**: Only users with access to the parent record can download  
- **Delete**: Only users with access to the parent record can delete
- **Button Visibility**: "New Attachment" button shows only if user has update permission

### Access Rules
- **Project**: Project member, team member, or organization member
- **Task**: Task assignee or project member
- **Scope**: Inherits project permissions
- **Team**: Team member or organization member
- **Organization**: Organization member

## Console Testing

```ruby
# Test Project attachments
project = Project.first
attachable = project.attachable || Attachable.create!(attachable: project)
attachment = attachable.attachments.create!(
  user: User.first,
  description: "Test attachment"
)
attachment.file.attach(
  io: File.open(Rails.root.join('README.md')),
  filename: 'README.md',
  content_type: 'text/markdown'
)

# Verify
project.reload
project.attachments.count # Should be > 0
project.attachments.first.filename # Should show "README.md"
project.attachments.first.file_size # Should show file size

# Test Task attachments
task = Task.first
attachable = task.attachable || Attachable.create!(attachable: task)
# ... same as above
```

## Troubleshooting

### "New Attachment" button not showing
- Verify you're logged in
- Verify you have `update?` permission on the parent record (Project, Task, Scope, Team, or Organization)
- Check browser console for JavaScript errors
- For development mode issues, see `docs/attachment_policy_fix.md`

### Upload fails
- Check file size (max 100MB)
- Verify Active Storage is configured correctly
- Check Rails logs for errors

### Attachments not appearing after upload
- Verify the redirect is working
- Check if Turbo is enabled
- Look for errors in Rails logs

### Download fails
- Verify Active Storage blob exists
- Check file permissions
- Verify signed URL is being generated

## Rails Console Verification

```bash
# Check routes
docker compose exec rails bash -lc "bin/rails routes | grep attachment"

# Check associations
docker compose exec rails bash -lc "bin/rails runner 'puts Project.reflect_on_all_associations.select { |a| a.name.to_s.include?(\"attach\") }.map(&:name).inspect'"

# Check Attachable model
docker compose exec rails bash -lc "bin/rails runner 'puts Attachable.reflect_on_all_associations.map(&:name).inspect'"
```
