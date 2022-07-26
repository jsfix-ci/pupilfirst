module Mutations
  class CreateCalendar < ApplicationQuery
    include QueryAuthorizeSchoolAdmin
    argument :course_id, ID, required: true
    argument :cohort_ids, [ID]
    argument :name,
             String,
             required: true,
             validates: {
               length: {
                 minimum: 1,
                 maximum: 50
               }
             }

    description 'Create a new calendar'

    field :success, Boolean, null: false

    def resolve(_params)
      notify(
        :success,
        I18n.t('shared.notifications.done_exclamation'),
        I18n.t('mutations.create_calendar.success_notification')
      )

      { cohort: create_calendar }
    end

    def create_calendar
      course.calendars.create!(name: @params[:name])
    end

    def course
      @course ||= current_school.courses.find(@params[:course_id])
    end

    def resource_school
      course&.school
    end
  end
end
