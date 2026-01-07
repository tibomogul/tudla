# Attachment Policy Fix

## Problem
The `AttachmentPolicy#create?` was returning `false` even when users had proper permissions through team membership. The policy check was failing during file uploads.

## Root Cause
**Rails Class Reloading in Development Mode**

In Rails development mode, classes are reloaded on each request. This causes the same class to have different object IDs in memory, breaking Ruby's pattern matching:

- `case/when` uses `===` operator which compares object identity
- `is_a?` and `kind_of?` also fail with reloaded classes
- The `Scope` class in the policy code was a different object than the `Scope` instance's class

## Solution
Changed from class-based pattern matching to **string-based class name comparison**:

```ruby
# Before (broken in development):
case attachable_record
when Project
  user_has_project_access?(attachable_record)
when Scope
  user_has_scope_access?(attachable_record)
# ...
end

# After (works in all environments):
case attachable_record.class.name
when "Project"
  user_has_project_access?(attachable_record)
when "Scope"
  user_has_scope_access?(attachable_record)
# ...
end
```

## Changes Made

### 1. AttachmentPolicy (`app/policies/attachment_policy.rb`)
- Changed `can_access_attachable?` to use `attachable_record.class.name` instead of class objects
- This approach works reliably in both development and production
- String comparison is immune to class reloading issues

### 2. View Permission Check Approach
- Moved permission check from partial to parent views
- Each show page passes `can_upload: policy(@record).update?`
- Cleaner separation of concerns
- Avoids complex temporary record creation

## Testing
Verified with console debugging that:
1. User has team access: ✅
2. Scope is correctly identified: ✅
3. `user_has_scope_access?` is called: ✅
4. `user_has_project_access?` checks team membership: ✅
5. Policy returns `true`: ✅

## Production Impact
This fix works in both development and production environments. In production, classes aren't reloaded, so both approaches would work, but string comparison is more robust.

## Related Issues
This is a common Rails gotcha documented in various places:
- Classes reload in development mode
- Pattern matching and type checks can fail
- String-based comparison is the recommended workaround
