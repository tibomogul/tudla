class OrganizationMailer < ApplicationMailer
  def user_added(user:, party:, added_by:)
    @user = user
    @party = party
    @added_by = added_by
    mail(to: @user.email, subject: "You've been added to #{@party.name}")
  end
end
