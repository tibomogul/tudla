class PitchesController < ApplicationController
  include ActionView::RecordIdentifier
  include OrganizationScoping

  before_action :set_pitch, only: %i[show edit update destroy transition bet]

  def index
    load_paginated_index_pitches
  end

  def show
    authorize @pitch
    @ingredients = {
      problem: @pitch.problem,
      appetite: @pitch.appetite,
      solution: @pitch.solution,
      rabbit_holes: @pitch.rabbit_holes,
      no_gos: @pitch.no_gos
    }
    @ingredients_complete = @pitch.ingredients_complete?
  end

  def new
    @pitch = Pitch.new
    @pitch.user = current_user
    authorize @pitch
    load_accessible_organizations
    @pitch.organization_id = @organization_ids.first if @organization_ids.one?
  end

  def create
    load_accessible_organizations
    @pitch = Pitch.new(pitch_params)
    @pitch.user = current_user
    @pitch.organization_id ||= @organization_ids.first if @organization_ids.one?
    authorize @pitch

    respond_to do |format|
      if @pitch.save
        format.html { redirect_to @pitch, notice: "Pitch was successfully created." }
        format.json { render :show, status: :created, location: @pitch }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @pitch.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @pitch
    load_accessible_organizations
  end

  def update
    authorize @pitch

    respond_to do |format|
      if @pitch.update(pitch_params)
        format.html { redirect_to @pitch, notice: "Pitch was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @pitch }
      else
        load_accessible_organizations
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @pitch.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @pitch
    @pitch.destroy

    respond_to do |format|
      format.html { redirect_to pitches_path, notice: "Pitch was successfully archived.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def transition
    new_state = params[:state].to_sym
    authorize_transition!(new_state)

    if @pitch.state_machine.can_transition_to?(new_state)
      @pitch.state_machine.transition_to!(new_state, user_id: current_user.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @pitch, notice: "Pitch moved to #{new_state}." }
      end
    else
      redirect_to @pitch, alert: "Cannot transition to #{new_state}."
    end
  end

  def bet
    authorize @pitch, :bet?

    project = nil
    Project.transaction do
      project = Project.create!(
        name: @pitch.title,
        description: @pitch.solution,
        pitch: @pitch,
        cycle_id: params[:cycle_id],
        team_id: params[:team_id]
      )
      @pitch.state_machine.transition_to!(:bet, user_id: current_user.id)
    end

    redirect_to project, notice: "Pitch was successfully bet and converted into a project."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @pitch, alert: e.message
  end

  private

  def set_pitch
    @pitch = policy_scope(Pitch).find(params.expect(:id))
  end

  def pitch_params
    params.expect(pitch: [ :title, :problem, :appetite, :solution, :rabbit_holes, :no_gos, :organization_id ])
  end

  def load_paginated_index_pitches
    @status_tab = params[:status].presence || "all"
    pitches = policy_scope(Pitch).includes(:user, :organization).order(updated_at: :desc)

    pitches = case @status_tab
    when "draft"
      pitches.where(status: "draft")
    when "ready_for_betting"
      pitches.where(status: "ready_for_betting")
    when "bet"
      pitches.where(status: "bet")
    when "rejected"
      pitches.where(status: "rejected")
    else
      pitches
    end

    @pagy_pitches, @pitches = pagy(:offset, pitches, limit: 20)
  end


  def authorize_transition!(new_state)
    case new_state
    when :ready_for_betting
      authorize @pitch, :submit?
    when :bet
      authorize @pitch, :bet?
    when :rejected
      authorize @pitch, :reject?
    when :draft
      authorize @pitch, :update?
    else
      authorize @pitch, :update?
    end
  end
end
