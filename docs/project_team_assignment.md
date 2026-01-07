# Project Team Assignment

This document describes how project-to-team assignment works and the authorization rules for creating projects.

## Authorization Rules

### Creating Projects

Users can create projects for teams based on their UserPartyRole:

1. **Organization Admins**: Can create projects for ANY team within that organization
2. **Team Admins**: Can create projects ONLY for that specific team

### Permission Hierarchy

```
Organization (admin role)
  └── Team A
      └── Can create projects
  └── Team B
      └── Can create projects
  └── Team C
      └── Can create projects

Team A (admin role)
  └── Can create projects ONLY for Team A
```

## Implementation

### User Model

The `User` model provides a helper method to get all teams where the user can create projects:

```ruby
class User < ApplicationRecord
  # Get all teams where user can create projects
  # This includes:
  # - Teams where user is admin
  # - All teams in organizations where user is admin
  def teams_for_project_creation
    # Teams where user has admin role
    admin_team_ids = user_party_roles
      .where(party_type: "Team", role: "admin")
      .pluck(:party_id)

    # Organizations where user has admin role
    admin_org_ids = user_party_roles
      .where(party_type: "Organization", role: "admin")
      .pluck(:party_id)

    # Get all teams in those organizations
    org_team_ids = Team.where(organization_id: admin_org_ids).pluck(:id)

    # Combine and get unique team IDs
    team_ids = (admin_team_ids + org_team_ids).uniq

    Team.where(id: team_ids).order(:name)
  end
end
```

### ProjectPolicy

The `ProjectPolicy` enforces these rules:

```ruby
class ProjectPolicy < ApplicationPolicy
  def create?
    # For new projects (no team set yet), check if user has ANY admin roles
    if project.team.nil?
      # Check if user is admin on any team or organization
      UserPartyRole.where(user: user, role: "admin")
        .where(party_type: ["Team", "Organization"])
        .exists?
    else
      # For existing projects or projects with team set, check specific team/org
      user_is_team_admin? || user_is_organization_admin?
    end
  end

  # Get teams where user can create projects
  # Returns Team relation
  def allowed_teams
    user.teams_for_project_creation
  end

  # Check if user can assign project to a specific team
  def can_assign_to_team?(team)
    return false unless team

    # Check if user is admin on the team
    team_role = UserPartyRole.where(user: user, party: team).first&.role
    return true if team_role == "admin"

    # Check if user is admin on the organization
    org_role = UserPartyRole.where(user: user, party: team.organization).first&.role
    return true if org_role == "admin"

    false
  end
end
```

### ProjectsController

The controller enforces authorization and provides the allowed teams to the view:

```ruby
class ProjectsController < ApplicationController
  # GET /projects/new
  def new
    @project = Project.new
    authorize @project
    @allowed_teams = policy(@project).allowed_teams
  end

  # GET /projects/1/edit
  def edit
    @allowed_teams = policy(@project).allowed_teams
  end

  # POST /projects
  def create
    @project = Project.new(project_params)
    authorize @project

    # Validate that user can assign to this team
    if @project.team && !policy(@project).can_assign_to_team?(@project.team)
      @project.errors.add(:team_id, "You don't have permission to create projects for this team")
    end

    respond_to do |format|
      if @project.errors.empty? && @project.save
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        @allowed_teams = policy(@project).allowed_teams
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1
  def update
    # Validate team change if team_id is being updated
    if params[:project][:team_id].present?
      new_team = Team.find_by(id: params[:project][:team_id])
      if new_team && !policy(@project).can_assign_to_team?(new_team)
        @project.errors.add(:team_id, "You don't have permission to assign projects to this team")
      end
    end

    respond_to do |format|
      if @project.errors.empty? && @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        @allowed_teams = policy(@project).allowed_teams
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def project_params
      params.expect(project: [ :name, :description, :team_id ])
    end
end
```

### View (Form)

The form displays only teams the user has permission to create projects for:

```erb
<div class="my-5">
  <%= form.label :team_id, "Team" %>
  <%= form.collection_select :team_id, @allowed_teams, :id, :name, 
      { prompt: "Select a team" }, 
      class: ["block shadow-sm rounded-md border px-3 py-2 mt-2 w-full", 
              {"border-gray-400 focus:outline-blue-600": project.errors[:team_id].none?, 
               "border-red-400 focus:outline-red-600": project.errors[:team_id].any?}] %>
</div>
```

## Examples

### Example 1: Organization Admin

Given:
- User "Alice" has admin role on Organization "Acme Corp"
- Acme Corp has teams: "R&D", "S&M", "Operations"

Then:
- Alice can create projects for ANY of these teams (R&D, S&M, Operations)
- The team dropdown will show all three teams

### Example 2: Team Admin

Given:
- User "Evan" has admin role on Team "R&D" (within Acme Corp organization)
- Acme Corp has teams: "R&D", "S&M", "Operations"

Then:
- Evan can create projects ONLY for "R&D" team
- The team dropdown will show only "R&D"

### Example 3: Multiple Admin Roles

Given:
- User "Bob" has:
  - Admin role on Team "S&M" (within Acme Corp)
  - Admin role on Team "Marketing" (within another organization)

Then:
- Bob can create projects for both "S&M" and "Marketing"
- The team dropdown will show both teams

## Validation

The system validates team assignment at multiple levels:

1. **View Level**: Dropdown only shows allowed teams
2. **Controller Level**: Validates submitted team_id is in allowed list
3. **Policy Level**: Enforces authorization rules

This defense-in-depth approach ensures security even if a malicious user tries to:
- Manipulate form data
- Make direct API calls
- Bypass client-side validation

## Error Messages

When a user tries to assign a project to an unauthorized team:

- **Create**: "You don't have permission to create projects for this team"
- **Update**: "You don't have permission to assign projects to this team"

## Database Schema

```ruby
# projects table
t.string :name
t.text :description
t.bigint :team_id  # Foreign key to teams table
t.string :risk_state
t.timestamps
```

## Testing

To test team assignment authorization:

1. **Setup test data**:
   ```ruby
   org = Organization.create!(name: "Test Org")
   team1 = Team.create!(name: "Team 1", organization: org)
   team2 = Team.create!(name: "Team 2", organization: org)
   
   org_admin = User.create!(username: "org_admin", email: "org@test.com", password: "password")
   team_admin = User.create!(username: "team_admin", email: "team@test.com", password: "password")
   
   UserPartyRole.create!(user: org_admin, party: org, role: "admin")
   UserPartyRole.create!(user: team_admin, party: team1, role: "admin")
   ```

2. **Test org admin can create projects for any team**:
   - Sign in as org_admin
   - Create project for team1 → Should succeed
   - Create project for team2 → Should succeed

3. **Test team admin can only create projects for their team**:
   - Sign in as team_admin
   - Create project for team1 → Should succeed
   - Create project for team2 → Should fail with authorization error

## Notes

- Projects MUST have a team assigned (team_id is effectively required)
- The team selection dropdown uses `collection_select` for better UX
- Team names are displayed in the project index and show pages
- Team links navigate to the team show page
- Authorization is enforced at both create and update actions
