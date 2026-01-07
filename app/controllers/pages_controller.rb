class PagesController < ApplicationController
  include DashboardLists
  skip_before_action :custom_authenticate_user!, only: :home

  def home
    redirect_to user_root_path if user_signed_in?
  end

  def dashboard
    params.permit(:project_id, :scope_id)
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
    @projects = policy_scope(Project).order(:name)
  end
end
