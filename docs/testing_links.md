# Testing Links Feature

## Manual Testing Steps

### 1. Navigate to a Show Page
Visit any of the following:
- Project show page: `/projects/:id`
- Task show page: `/tasks/:id`
- Scope show page: `/scopes/:id`
- Team show page: `/teams/:id`
- Organization show page: `/organizations/:id`

### 2. Look for the Links Section
At the bottom of the page (after Notes), you should see:
- **Section Header**: "Links" with a count badge
- **"New Link" button**: Primary blue button with a plus icon (if you have permission)
- **Empty State**: "No links yet. Add your first link to get started." (if no links exist)

### 3. Click "New Link" Button
- A modal dialog should open with the title "New Link"
- The modal contains:
  - URL field (required) with placeholder "https://example.com"
  - Helper text: "Full URL including http:// or https://"
  - Description textarea (optional)
  - "Cancel" button (closes modal)
  - "Add Link" button (primary blue, with plus icon)

### 4. Create a Link
1. Enter a full URL (must include http:// or https://)
2. Optionally add a description
3. Click "Add Link"
4. Page should refresh
5. Modal should close
6. New link should appear in the list

### 5. Verify Link Display
Each link card should show:
- Link icon (chain/link symbol)
- Clickable URL (opens in new tab)
- External link icon next to URL
- Domain name below URL (e.g., "github.com")
- Description (if provided)
- Author name and timestamp
- "(edited)" indicator if modified
- Edit button (pencil icon, only for your own links)
- Delete button (trash icon, only for your own links)
- Hover effect on card

### 6. Test Link Navigation
- Click any URL in the list
- Should open in a new browser tab
- Verify external site loads correctly

### 7. Edit a Link
- Click the edit (pencil) icon on your own link
- Edit page should open
- See URL and description fields
- Make changes and click "Update Link"
- Should redirect back to parent record
- Changes should be reflected in the link

### 8. Delete a Link
- Click the delete (trash) icon on your own link
- Confirm deletion in dialog
- Page should refresh
- Link should be removed from the list

## Expected Behavior

### Permissions
- **Create**: Only users with `update?` permission on the parent record can create links
- **Edit**: Only the link author can edit their own links
- **Delete**: Only the link author can delete their own links
- **View**: All users with access to the parent record can view links
- **Button Visibility**: "New Link" button shows only if user has update permission

### Access Rules
- **Project**: Project member, team member, or organization member
- **Task**: Task assignee or project member
- **Scope**: Inherits project permissions
- **Team**: Team member or organization member
- **Organization**: Organization member

### URL Validation
- URL must start with `http://` or `https://`
- Browser-level validation for URL format
- Server-side validation ensures proper format
- Invalid URLs should show error message

## Console Testing

```ruby
# Test Project links
project = Project.first
linkable = project.linkable || Linkable.create!(linkable: project)
link = linkable.links.create!(
  user: User.first,
  url: "https://github.com/example/repo",
  description: "Project repository"
)

# Verify
project.reload
project.links.count # Should be > 0
project.links.first.url # Should show URL
project.links.first.domain # Should show domain

# Test domain extraction
link.domain # Should return "github.com"

# Test URL validation
invalid_link = linkable.links.build(
  user: User.first,
  url: "not-a-valid-url"
)
invalid_link.valid? # Should be false
invalid_link.errors[:url] # Should show validation error

# Test Task links
task = Task.first
linkable = task.linkable || Linkable.create!(linkable: task)
# ... same as above
```

## Troubleshooting

### "New Link" button not showing
- Verify you're logged in
- Verify you have `update?` permission on the parent record (Project, Task, Scope, Team, or Organization)
- Check browser console for JavaScript errors
- For development mode issues, see `docs/attachment_policy_fix.md` (same pattern applies)

### Link creation fails
- Verify URL starts with http:// or https://
- Check URL format is valid
- Check Rails logs for errors
- Verify Linkable record is created correctly

### URL validation errors
- Ensure URL includes protocol (http:// or https://)
- Check for typos in URL
- Test URL in browser to confirm it's accessible
- Some special characters may need encoding

### Edit/Delete buttons not showing
- Verify you are the author of the link
- Only the link author can edit/delete their own links
- Check that current_user matches link.user

### Links not appearing after creation
- Verify the redirect is working
- Check if Turbo is enabled
- Look for errors in Rails logs
- Verify Linkable association is correct

### Domain extraction not working
- Check if URL is valid
- Verify URI parsing is working
- Should gracefully handle invalid URLs

## Rails Console Verification

```bash
# Check routes
docker compose exec rails bash -lc "bin/rails routes | grep link"

# Check associations
docker compose exec rails bash -lc "bin/rails runner 'puts Project.reflect_on_all_associations.select { |a| a.name.to_s.include?(\"link\") }.map(&:name).inspect'"

# Check Linkable model
docker compose exec rails bash -lc "bin/rails runner 'puts Linkable.reflect_on_all_associations.map(&:name).inspect'"

# Test URL validation
docker compose exec rails bash -lc "bin/rails runner 'link = Link.new(url: \"invalid\"); puts link.valid?; puts link.errors.full_messages'"

# Test domain extraction
docker compose exec rails bash -lc "bin/rails runner 'link = Link.new(url: \"https://github.com/user/repo\"); puts link.domain'"
```

## Testing Checklist

- [ ] Create link on Project
- [ ] Create link on Task
- [ ] Create link on Scope
- [ ] Create link on Team
- [ ] Create link on Organization
- [ ] Link opens in new tab
- [ ] External link icon displayed
- [ ] Domain extracted correctly
- [ ] Edit own link
- [ ] Delete own link
- [ ] Cannot edit others' links
- [ ] Cannot delete others' links
- [ ] URL validation works (requires http/https)
- [ ] Description is optional
- [ ] Empty state shows when no links exist
- [ ] Link count badge updates correctly
- [ ] "(edited)" indicator appears after editing
- [ ] Permissions work correctly for all record types
- [ ] Hover effect on link cards
