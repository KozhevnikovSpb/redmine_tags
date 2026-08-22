# frozen_string_literal: true

# TagCloud — multi-project capable tag cloud definition.
# Schema: no project_id / is_system / position on this table.
# Position lives in tag_cloud_projects (per project). Default system cloud is virtual (not stored).
class TagCloud < ActiveRecord::Base
  VISIBILITIES = %w[all owner roles].freeze

  # Same operator codes as Redmine 7 Issue Query
  # status_id: list_status
  # tracker_id: list_with_history (+ * = no extra filter, row always visible)
  # fixed_version_id: list_optional_with_history (+ * = no extra filter)
  STATUS_OPERATORS  = %w[o = ! ev !ev cf c *].freeze
  VERSION_OPERATORS = %w[= ! ev !ev cf !* *].freeze
  TRACKER_OPERATORS = %w[= ! ev !ev cf *].freeze
  VALUE_OPERATORS   = %w[= ! ev !ev cf].freeze
  OPERATOR_COLUMNS  = %w[status_operator version_operator tracker_operator].freeze

  has_many :tag_cloud_projects, dependent: :destroy, inverse_of: :tag_cloud
  has_many :projects, through: :tag_cloud_projects

  has_many :tag_cloud_tags, dependent: :destroy
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
  validates :status_operator, inclusion: { in: STATUS_OPERATORS }, if: :operator_columns?
  validates :version_operator, inclusion: { in: VERSION_OPERATORS }, if: :operator_columns?
  validates :tracker_operator, inclusion: { in: TRACKER_OPERATORS }, if: :operator_columns?

  validate :name_unique_within_projects
  validate :status_filter_exists
  validate :roles_present_when_visibility_roles

  before_validation :normalize_operators
  before_validation :normalize_filters
  before_validation :normalize_owner_for_visibility

  scope :for_project, lambda { |project|
    joins(:tag_cloud_projects)
      .where(tag_cloud_projects: { project_id: project.id })
      .order(Arel.sql('tag_cloud_projects.position ASC, tag_clouds.id ASC'))
  }

  def self.operator_columns?
    column_names.include?('status_operator')
  end

  def self.for_sidebar(project)
    return none unless project

    clouds = []
    seen = {}

    chain = project.self_and_ancestors.to_a
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

  def status_needs_values?
    VALUE_OPERATORS.include?(normalized_status_operator)
  end

  def version_needs_values?
    VALUE_OPERATORS.include?(normalized_version_operator)
  end

  def tracker_needs_values?
    VALUE_OPERATORS.include?(normalized_tracker_operator)
  end

  def normalized_status_operator
    normalize_operator_code(read_filter_operator(:status_operator), STATUS_OPERATORS)
  end

  def normalized_version_operator
    normalize_operator_code(read_filter_operator(:version_operator), VERSION_OPERATORS)
  end

  def normalized_tracker_operator
    normalize_operator_code(read_filter_operator(:tracker_operator), TRACKER_OPERATORS)
  end

  def operator_columns?
    self.class.operator_columns?
  end

  private

  def read_filter_operator(name)
    return '*' unless operator_columns?

    self[name].to_s.presence || '*'
  rescue StandardError
    '*'
  end

  def normalize_operator_code(op, allowed)
    code = op.to_s.presence || '*'
    allowed.include?(code) ? code : '*'
  end

  def normalize_operators
    return unless operator_columns?

    self.status_operator = normalized_status_operator
    self.version_operator = normalized_version_operator
    self.tracker_operator = normalized_tracker_operator
  rescue StandardError
    self.status_operator = '*' if has_attribute?(:status_operator) && status_operator.blank?
    self.version_operator = '*' if has_attribute?(:version_operator) && version_operator.blank?
    self.tracker_operator = '*' if has_attribute?(:tracker_operator) && tracker_operator.blank?
  end

  def normalize_filters
    %i[status_filter version_filter tracker_filter].each do |attr|
      values = self[attr]
      values = values.split(/[,\s]+/) if values.is_a?(String)
      self[attr] = Array(values).map(&:to_i).uniq.reject(&:zero?)
    end
    self.status_filter = [] unless status_needs_values?
    self.version_filter = [] unless version_needs_values?
    self.tracker_filter = [] unless tracker_needs_values?
  end

  def normalize_owner_for_visibility
    case visibility
    when 'owner'
      self.owner_id ||= User.current&.id
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
