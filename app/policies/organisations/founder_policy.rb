module Organisations
  class FounderPolicy < ApplicationPolicy
    def show?
      return false if record.school != current_school

      return true if current_school_admin.present?

      user.organisations.where(id: record.user.organisation_id).present?
    end

    alias submissions? show?
  end
end
