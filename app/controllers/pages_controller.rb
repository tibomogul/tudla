class PagesController < ApplicationController
  include DashboardLists
  skip_before_action :custom_authenticate_user!, only: :home

  def home
    redirect_to user_root_path if user_signed_in?
  end

  def dashboard
    params.permit(:project_id, :scope_id, :project_name, :page)

    load_paginated_projects

    if turbo_frame_request_id == "projects_list"
      render partial: "pages/projects_list_content", locals: {
        pagy_projects: @pagy_projects,
        projects: @projects
      }
      return
    end

    tasks = policy_scope(Task).where(responsible_user_id: current_user.id)

    if params[:project_id].present?
      tasks = tasks.where(project_id: params[:project_id])
    end

    if params[:scope_id].present?
      tasks = tasks.where(scope_id: params[:scope_id])
    end

    lists = compute_dashboard_lists(tasks)
    @today_tasks = lists[:today]
    @backlog_tasks = lists[:backlog]
    @completed_today_tasks = lists[:completed_today]
  end

  private

  def load_paginated_projects
    # Eager load :team to avoid N+1 queries in the view.
    # Use a SQL subquery to compute tasks_count per project in a single query,
    # avoiding N+1 from calling project.tasks.count in the loop.
    # The subquery excludes soft-deleted tasks (deleted_at IS NULL).
    # The resulting attribute is accessible as project.tasks_count in the view.
    projects = policy_scope(Project)
                .includes(:team)
                .select("projects.*, (SELECT COUNT(*) FROM tasks WHERE tasks.project_id = projects.id AND tasks.deleted_at IS NULL) AS tasks_count")
                .order(:name)

    if params[:project_name].present?
      projects = projects.where("name ILIKE ?", "%#{params[:project_name]}%")
    end

    @pagy_projects, @projects = pagy(:offset, projects)
  end
end
