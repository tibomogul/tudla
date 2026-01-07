class LinksController < ApplicationController
  before_action :set_linkable, only: [:create]
  before_action :set_link, only: [:edit, :update, :destroy]

  def create
    @link = @linkable.links.build(link_params)
    @link.user = current_user

    authorize @link

    if @link.save
      redirect_to polymorphic_path(@linkable.linkable), notice: "Link was successfully created."
    else
      redirect_to polymorphic_path(@linkable.linkable), alert: "Failed to create link: #{@link.errors.full_messages.join(', ')}"
    end
  end

  def edit
    authorize @link
    # Render edit form in a modal or dedicated page
  end

  def update
    authorize @link

    if @link.update(link_params)
      redirect_to polymorphic_path(@link.linkable.linkable), notice: "Link was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @link
    linkable_record = @link.linkable.linkable
    @link.destroy

    redirect_to polymorphic_path(linkable_record), notice: "Link was successfully deleted."
  end

  private

  def set_linkable
    linkable_type = params[:linkable_type]
    linkable_id = params[:linkable_id]

    # Find or create the linkable record
    @linkable = Linkable.find_or_create_by!(
      linkable_type: linkable_type,
      linkable_id: linkable_id
    )
  end

  def set_link
    @link = Link.find(params[:id])
  end

  def link_params
    params.require(:link).permit(:url, :description)
  end
end
