class CyclesController < ApplicationController
  include ActionView::RecordIdentifier
  include OrganizationScoping

  before_action :set_cycle, only: %i[show edit update destroy transition betting_table]

  def index
    load_paginated_index_cycles
  end

  def show
    authorize @cycle
    @unfinished_projects = @cycle.unfinished_projects.includes(:team, :pitch).order(:name)
    @finished_projects = @cycle.finished_projects.includes(:team, :pitch).order(:name)
    @progress_percentage = @cycle.progress_percentage
    @days_remaining = @cycle.days_remaining
    @build_phase = @cycle.build_phase?
    @cooldown_phase = @cycle.cooldown_phase?
  end

  def new
    @cycle = Cycle.new
    authorize @cycle
    load_accessible_organizations
    @cycle.organization_id = @organization_ids.first if @organization_ids.one?
  end

  def create
    load_accessible_organizations
    @cycle = Cycle.new(cycle_params)
    @cycle.organization_id ||= @organization_ids.first if @organization_ids.one?
    authorize @cycle

    respond_to do |format|
      if @cycle.save
        format.html { redirect_to @cycle, notice: "Cycle was successfully created." }
        format.json { render :show, status: :created, location: @cycle }
      else
        load_accessible_organizations
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @cycle.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @cycle
    load_accessible_organizations
  end

  def update
    authorize @cycle

    respond_to do |format|
      if @cycle.update(cycle_params)
        format.html { redirect_to @cycle, notice: "Cycle was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @cycle }
      else
        load_accessible_organizations
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @cycle.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @cycle
    @cycle.destroy

    respond_to do |format|
      format.html { redirect_to cycles_path, notice: "Cycle was successfully archived.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def transition
    authorize @cycle, :update?
    new_state = params[:state].to_sym

    if @cycle.state_machine.can_transition_to?(new_state)
      @cycle.state_machine.transition_to!(new_state, user_id: current_user.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @cycle, notice: "Cycle moved to #{new_state}." }
      end
    else
      redirect_to @cycle, alert: "Cannot transition to #{new_state}."
    end
  end

  def betting_table
    authorize @cycle, :show?
    @betting_enabled = @cycle.current_state.in?(%w[shaping betting])

    betting_pitches = policy_scope(Pitch)
      .where(organization_id: @cycle.organization_id, status: %w[ready_for_betting bet rejected])
      .includes(:user, projects: :team)
      .order(updated_at: :desc)

    # Bet/rejected pitches only shown if they have a project linked to this cycle
    ready_pitches = betting_pitches.where(status: "ready_for_betting")
    bet_pitches = betting_pitches.where(status: %w[bet rejected])
      .joins(:projects).where(projects: { cycle_id: @cycle.id })

    all_pitches = (ready_pitches + bet_pitches).uniq

    pitches_by_appetite = all_pitches.group_by { |pitch| (pitch.appetite == 2) ? :small_batch : :big_batch }
    @small_batch_pitches = pitches_by_appetite[:small_batch] || []
    @big_batch_pitches = pitches_by_appetite[:big_batch] || []
    @teams = Team.active.where(organization_id: @cycle.organization_id).includes(:users).order(:name)
  end

  private

  def set_cycle
    @cycle = policy_scope(Cycle).find(params.expect(:id))
  end

  def cycle_params
    params.expect(cycle: [ :name, :start_date, :end_date, :organization_id ])
  end

  def load_paginated_index_cycles
    load_accessible_organizations
    cycles = policy_scope(Cycle).includes(:organization).order(start_date: :desc)

    if params[:organization_id].present?
      cycles = cycles.where(organization_id: params[:organization_id])
    end

    @pagy_cycles, @cycles = pagy(:offset, cycles, limit: 20)
  end
end
