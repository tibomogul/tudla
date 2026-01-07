class NotesController < ApplicationController
  before_action :set_notable, only: [:create]
  before_action :set_note, only: [:edit, :update, :destroy]

  def create
    @note = @notable.notes.build(note_params)
    @note.user = current_user

    authorize @note

    if @note.save
      redirect_to polymorphic_path(@notable.notable), notice: "Note was successfully created."
    else
      redirect_to polymorphic_path(@notable.notable), alert: "Failed to create note: #{@note.errors.full_messages.join(', ')}"
    end
  end

  def edit
    authorize @note
    # Render edit form in a modal or dedicated page
  end

  def update
    authorize @note

    if @note.update(note_params)
      redirect_to polymorphic_path(@note.notable.notable), notice: "Note was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @note
    notable_record = @note.notable.notable
    @note.destroy

    redirect_to polymorphic_path(notable_record), notice: "Note was successfully deleted."
  end

  private

  def set_notable
    notable_type = params[:notable_type]
    notable_id = params[:notable_id]

    # Find or create the notable record
    @notable = Notable.find_or_create_by!(
      notable_type: notable_type,
      notable_id: notable_id
    )
  end

  def set_note
    @note = Note.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:title, :content)
  end
end
