# frozen_string_literal: true

# TagCloud — multi-project capable tag cloud definition.
# Schema: no project_id / is_system / position on this table.
# Position lives in tag_cloud_projects (per project). Default system cloud is virtual (not stored).
class TagCloud < ActiveRecord::Base
  VISIBILITIES = %w[all owner roles].freeze

  has_many :tag_cloud_projects, dependent: :destroy, inverse_of: :tag_cloud
  has_many :projects, through: :tag_cloud_projects

  has_many :tag_cloud_tags, dependent: :destroy
  # Absolute :: path — relative 'Redmineup::Tag' resolves as TagCloud::Redmineup::Tag under Zeitwerk/Ruby 3.4
  has_many :tags, through: :tag_cloud_tags, class_name: '::Redmineup::Tag', source: :tag

  has_many :tag_cloud_roles, dependent: :destroy
  has_many :roles, through: :tag_cloud_roles

  has_many :preferences, class_name: 'TagCloudPreference', dependent: :delete_all, inverse_of: :tag_cloud

  belongs_to :owner, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true, foreign_key: :created_by_id

  serialize :status_filter, coder: YAML, type: Array
  serialize :version_filter, coder: YAML, type: Array
  serialize :tracker_filter, coder: YAML, type: Array

  validates :name, presence: true
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :tag_filter, inclusion: { in: [true, false] }
  validates :include_subprojects, inclusion: { in: [true, false] }
  validates :visible_by_default, inclusion: { in: [true, false] }

  validate :name_unique_within_projects
  validate :status_filter_exists
  validate :roles_present_when_visibility_roles

  before_validation :normalize_filters
  before_validation :normalize_owner_for_visibility

  # Clouds directly linked to the project (settings + local sidebar).
  scope :for_project, lambda { |project|
    joins(:tag_cloud_projects)
      .where(tag_cloud_projects: { project_id: project.id })
      .order(Arel.sql('tag_cloud_projects.position ASC, tag_clouds.id ASC'))
  }

  # Sidebar: local clouds + ancestor clouds marked include_subprojects.
  # Order: root → … → parent (inherited), then local project order.
  def self.for_sidebar(project)
    return none unless project

    clouds = []
    seen = {}

    chain = project.self_and_ancestors.to_a
    # self_and_ancestors is usually root-first (by lft); ensure stable order
    chain = chain.sort_by(&:lft)

    chain.each do |p|
      scope = for_project(p)
      scope = scope.where(include_subprojects: true) if p.id != project.id
      scope.each do |cloud|
        next if seen[cloud.id]

        clouds << cloud
        seen[cloud.id] = true
      end
    end

    clouds
  end

  # Project the cloud is attached to for the current view context
  # (local link, else nearest ancestor link). Used for aggregation.
  def home_project_for(view_project)
    return nil unless view_project
    return view_project if linked_to?(view_project)

    view_project.ancestors.reorder(lft: :desc).each do |anc|
      return anc if linked_to?(anc)
    end

    projects.first
  end

  def visible_for?(user, project: nil)
    return false if user.nil?

    if user.logged? && project && user.allowed_to?(:select_tag_clouds, project)
      pref = preferences.find_by(user_id: user.id)
      return pref.visible? if pref
    end

    case visibility
    when 'all'
      visible_by_default?
    when 'owner'
      user.logged? && owner_id.present? && owner_id == user.id
    when 'roles'
      return false unless user.logged? && project

      user_role_ids = user.roles_for_project(project).map(&:id)
      (assigned_role_ids & user_role_ids).any?
    else
      false
    end
  end

  def position_in(project)
    return nil unless project

    tag_cloud_projects.find_by(project_id: project.id)&.position
  end

  def linked_to?(project)
    return false unless project

    tag_cloud_projects.exists?(project_id: project.id)
  end

  def assigned_role_ids
    if association(:tag_cloud_roles).loaded? || (new_record? && tag_cloud_roles.target.any?)
      tag_cloud_roles.map(&:role_id)
    else
      tag_cloud_roles.pluck(:role_id)
    end
  end

  def assigned_tag_ids
    if association(:tag_cloud_tags).loaded? || (new_record? && tag_cloud_tags.target.any?)
      tag_cloud_tags.map(&:tag_id)
    else
      tag_cloud_tags.pluck(:tag_id)
    end
  end

  def tag_ids
    assigned_tag_ids
  end

  def role_ids
    assigned_role_ids
  end

  def tag_ids=(ids)
    ids = Array(ids).map(&:to_i).reject(&:zero?).uniq
    if persisted?
      tag_cloud_tags.where.not(tag_id: ids).delete_all
      existing = tag_cloud_tags.pluck(:tag_id)
      (ids - existing).each { |tid| tag_cloud_tags.create!(tag_id: tid) }
    else
      tag_cloud_tags.target.clear
      ids.each { |tid| tag_cloud_tags.build(tag_id: tid) }
    end
  end

  def role_ids=(ids)
    ids = Array(ids).map(&:to_i).reject(&:zero?).uniq
    if persisted?
      tag_cloud_roles.where.not(role_id: ids).delete_all
      existing = tag_cloud_roles.pluck(:role_id)
      (ids - existing).each { |rid| tag_cloud_roles.create!(role_id: rid) }
    else
      tag_cloud_roles.target.clear
      ids.each { |rid| tag_cloud_roles.build(role_id: rid) }
    end
  end

  private

  def normalize_filters
    %i[status_filter version_filter tracker_filter].each do |attr|
      values = self[attr]
      values = values.split(/[,\s]+/) if values.is_a?(String)
      self[attr] = Array(values).map(&:to_i).uniq.reject(&:zero?)
    end
  end

  def normalize_owner_for_visibility
    case visibility
    when 'owner'
      self.owner_id ||= User.current&.id
    when 'all'
      # keep owner if set historically; not required
    when 'roles'
      # owner not used for visibility decision
    end
  end

  def name_unique_within_projects
    return if name.blank?
    return if projects.empty? && tag_cloud_projects.empty?

    project_ids = projects.map(&:id).presence || tag_cloud_projects.map(&:project_id)
    return if project_ids.blank?

    conflict = self.class
                   .joins(:tag_cloud_projects)
                   .where(tag_cloud_projects: { project_id: project_ids })
                   .where(name: name)
    conflict = conflict.where.not(id: id) if persisted?
    errors.add(:name, :taken) if conflict.exists?
  end

  def status_filter_exists
    return if status_filter.blank?

    invalid = status_filter - IssueStatus.where(id: status_filter).pluck(:id)
    errors.add(:status_filter, :invalid) if invalid.any?
  end

  def roles_present_when_visibility_roles
    return unless visibility == 'roles'
    return if assigned_role_ids.any?

    errors.add(:roles, :blank)
  end
end
