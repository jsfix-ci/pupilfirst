class Cohort < ApplicationRecord
  belongs_to :course
  has_many :teams, dependent: :destroy
  has_many :founders, dependent: :destroy
  has_many :faculty_cohort_enrollments, dependent: :destroy
  has_many :faculty, through: :faculty_cohort_enrollments
  has_one :school, through: :course
  has_many :caledars, through: :calendar_cohorts

  scope :active,
        -> { where('ends_at > ?', Time.zone.now).or(where(ends_at: nil)) }

  normalize_attribute :description

  def ended?
    ends_at.present? && ends_at.past?
  end
end
