class TagCloud < ActiveRecord::Base
  belongs_to :project
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :preferences, class_name: 'TagCloudPreference', dependent: :delete_all

  serialize :status_filter, coder: YAML, type: Array
  serialize :version_filter, coder: YAML, type: Array
  serialize :tracker_filter, coder: YAML, type: Array

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :project, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :single_system_cloud
  validate :filters_belong_to_project

  default_scope { order(:position, :id) }

  before_validation :normalize_filters

  def is_system?
    is_system == true
  end

  def visible_for?(user)
    preference = preferences.find_by(user_id: user.id) if user&.logged?
    preference.nil? ? visible_by_default? : preference.visible?
  end

  def self.ensure_system_cloud(project)
    return unless project&.persisted?

    project.with_lock do
      existing = project.tag_clouds.unscoped.where(is_system: true).order(:id).to_a
      if existing.any?
        # Keep the oldest system cloud; remove accidental duplicates
        keep = existing.first
        (existing - [keep]).each(&:destroy)
        keep
      else
        project.tag_clouds.unscoped.create!(
          name: I18n.t(:label_default_tag_cloud, default: 'Default Tags'),
          visible_by_default: true,
          is_system: true,
          position: 0,
          created_by: (User.current if User.current&.persisted?)
        )
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    project.tag_clouds.unscoped.where(is_system: true).order(:id).first
  end

  private

  def normalize_filters
    %i[status_filter version_filter tracker_filter].each do |attr|
      values = self[attr]
      values = values.split(/[,\s]+/) if values.is_a?(String)
      self[attr] = Array(values).map(&:to_i).uniq.reject(&:zero?)
    end
  end

  def single_system_cloud
    return unless is_system? && project_id

    duplicate = self.class.unscoped.where(project_id: project_id, is_system: true)
    duplicate = duplicate.where.not(id: id) if persisted?
    errors.add(:is_system, :taken) if duplicate.exists?
  end

  def filters_belong_to_project
    return unless project

    invalid_trackers = tracker_filter - project.trackers.where(id: tracker_filter).pluck(:id)
    invalid_versions = version_filter - project.versions.where(id: version_filter).pluck(:id)
    invalid_statuses = status_filter - IssueStatus.where(id: status_filter).pluck(:id)

    errors.add(:tracker_filter, :invalid) if invalid_trackers.any?
    errors.add(:version_filter, :invalid) if invalid_versions.any?
    errors.add(:status_filter, :invalid) if invalid_statuses.any?
  end
end
