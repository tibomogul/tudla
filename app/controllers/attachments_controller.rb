class AttachmentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_attachment, only: %i[destroy download]
  before_action :set_attachable, only: %i[create]

  # POST /attachments
  def create
    @attachment = @attachable.attachments.build(attachment_params)
    @attachment.user = current_user
    authorize @attachment

    if @attachment.save
      redirect_to polymorphic_path(@attachable.attachable), notice: "Attachment was successfully uploaded."
    else
      redirect_to polymorphic_path(@attachable.attachable), alert: "Failed to upload attachment: #{@attachment.errors.full_messages.join(', ')}"
    end
  end

  # DELETE /attachments/1
  def destroy
    attachable_record = @attachment.attachable.attachable
    @attachment.destroy!

    redirect_to polymorphic_path(attachable_record), notice: "Attachment was successfully deleted.", status: :see_other
  end

  # GET /attachments/1/download
  def download
    authorize @attachment
    redirect_to rails_blob_path(@attachment.file, disposition: "attachment"), allow_other_host: true
  end

  private

  def set_attachment
    @attachment = Attachment.find(params.expect(:id))
    authorize @attachment
  end

  def set_attachable
    attachable_type = params[:attachable_type]
    attachable_id = params[:attachable_id]

    # Find or create the attachable record
    @attachable = Attachable.find_or_create_by!(
      attachable_type: attachable_type,
      attachable_id: attachable_id
    )
  end

  def attachment_params
    params.require(:attachment).permit(:file, :description)
  end
end
