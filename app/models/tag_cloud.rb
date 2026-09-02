# frozen_string_literal: true

# TagCloud — multi-project capable tag cloud definition.
# Schema: no project_id / is_system / position on this table.
# Position lives in tag_cloud_projects (per project). Default system cloud is virtual (not stored).
class TagCloud < ActiveRecord::Base
  VISIBILITIES = %w[all owner roles].freeze
  NAME_MAX_LENGTH = 100

  STATUS_OPERATORS  = %w[o = ! ev !ev cf c *].freeze
  VERSION_OPERATORS = %w[= ! ev !ev cf !* *].freeze
  TRACKER_OPERATORS = %w[= ! ev !ev cf *].freeze
  TAG_OPERATORS     = %w[= ! !* *].freeze
  VALUE_OPERATORS   = %w[= ! ev !ev cf].freeze
  TAG_VALUE_OPERATORS = %w[= !].freeze
  OPERATOR_COLUMNS  = %w[status_operator version_operator tracker_operator tag_operator].freeze

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

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :tag_filter, inclusion: { in: [true, false] }
  validates :include_subprojects, inclusion: { in: [true, false] }
  validates :visible_by_default, inclusion: { in: [true, false] }
  validates :status_operator, inclusion: { in: STATUS_OPERATORS }, if: :operator_columns?
  validates :version_operator, inclusion: { in: VERSION_OPERATORS }, if: :operator_columns?
  validates :tracker_operator, inclusion: { in: TRACKER_OPERATORS }, if: :operator_columns?
  validates :tag_operator, inclusion: { in: TAG_OPERATORS }, if: :tag_operator_column?
  validate :name_unique_within_projects
  validate :status_filter_exists
  validate :roles_present_when_visibility_roles
  validate :owner_visibility_only_for_author
  before_validation :normalize_operators
  before_validation :normalize_filters
  before_validation :normalize_owner_for_visibility

  scope :for_project, lambda { |project|
    joins(:tag_cloud_projects)
      .where(tag_cloud_projects: { project_id: project.id })
      .order(Arel.sql('tag_cloud_projects.position ASC, tag_clouds.id ASC'))
  }

  def self.operator_columns?
    table_exists? && column_names.include?('status_operator')
  rescue StandardError
    false
  end

  def self.tag_operator_column?
    table_exists? && column_names.include?('tag_operator')
  rescue StandardError
    false
  end

  def self.ensure_operator_schema!
    return true if operator_columns? && tag_operator_column?
    return false unless defined?(RedmineupTags::SchemaRepair)
    RedmineupTags::SchemaRepair.ensure_operators!(verbose: false)
    reset_column_information
    operator_columns? && tag_operator_column?
  rescue StandardError => e
    Rails.logger.warn("[redmineup_tags] ensure_operator_schema: #{e.class}: #{e.message}") if defined?(Rails) && Rails.logger
    false
  end

  def self.inherited_for(project)
    return [] unless project && project.respond_to?(:ancestors)
    clouds = []
    seen = {}
    project.ancestors.reorder(:lft).each do |ancestor|
      for_project(ancestor).where(include_subprojects: true).each do |cloud|
        next if seen[cloud.id]
        clouds << cloud
        seen[cloud.id] = true
      end
    end
    clouds
  end

  def self.for_sidebar(project)
    return [] unless project
    inherited_for(project) + for_project(project).to_a
  end

  def self.can_see_custom_clouds?(user, project)
    return false unless user
    return true if user.admin?
    return false unless project
    %i[view_tag_clouds select_tag_clouds manage_tag_clouds].any? { |permission| user.allowed_to?(permission, project) }
  end

  def self.can_select_display?(user, project)
    return false unless user
    return true if user.admin?
    return false unless project
    user.allowed_to?(:select_tag_clouds, project) || user.allowed_to?(:manage_tag_clouds, project)
  end

  def self.can_manage?(user, project)
    return false unless user
    return true if user.admin?
    return false unless project
    user.allowed_to?(:manage_tag_clouds, project)
  end

  def self.can_view_settings_list?(user, project)
    return false unless user
    return true if user.admin?
    return false unless project
    user.allowed_to?(:view_tag_clouds, project) || user.allowed_to?(:manage_tag_clouds, project)
  end

  def self.sidebar_clouds_for(project, user)
    return [] unless can_see_custom_clouds?(user, project)

    for_sidebar(project).select { |cloud| cloud.visible_for?(user, project: project) }
  end

  def home_project_for(view_project)
    return nil unless view_project
    return view_project if linked_to?(view_project)
    view_project.ancestors.reorder(lft: :desc).each { |anc| return anc if linked_to?(anc) }
    projects.first
  end

  def visibility_author
    created_by || owner
  end

  def author_only?
    visibility.to_s == 'owner'
  end

  def author_ids
    [created_by_id, owner_id].compact.map(&:to_i).reject(&:zero?).uniq
  end

  def authored_by?(user)
    return false unless user&.logged?

    author_ids.include?(user.id.to_i)
  end

  def can_set_owner_visibility?(user = User.current)
    return false unless user&.logged?
    return true if user.admin?
    return true unless persisted?
    return true if author_ids.empty?

    authored_by?(user)
  end

  def listed_in_settings_for?(user, project: nil, context: :project)
    return false if user.nil?

    if context.to_sym == :admin
      return user.admin?
    end

    if author_only?
      return false unless authored_by?(user)
      return false unless project
      return true if user.admin?
      return user.allowed_to?(:manage_tag_clouds, project)
    end

    return true if user.admin?
    return false unless project
    self.class.can_view_settings_list?(user, project)
  end

  def manageable_by?(user, project: nil, context: :project)
    return false if user.nil?

    if context.to_sym == :admin
      return user.admin?
    end

    if author_only?
      return false unless authored_by?(user)
      return false unless project
      return true if user.admin?
      return user.allowed_to?(:manage_tag_clouds, project)
    end

    return true if user.admin?
    return false unless project
    user.allowed_to?(:manage_tag_clouds, project)
  end

  def visible_for?(user, project: nil)
    return false if user.nil?

    if author_only?
      return false unless authored_by?(user)
      return false unless self.class.can_see_custom_clouds?(user, project)

      preferred = personal_visibility(user, project)
      return preferred unless preferred.nil?

      return true
    end

    return false unless self.class.can_see_custom_clouds?(user, project)

    preferred = personal_visibility(user, project)
    return preferred unless preferred.nil?

    case visibility.to_s
    when 'all'
      visible_by_default?
    when 'roles'
      return true if user.admin?
      roles_match?(user, project)
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

  def inherited_in?(project)
    return false unless project
    include_subprojects? && !linked_to?(project)
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

  def tag_needs_values?
    TAG_VALUE_OPERATORS.include?(normalized_tag_operator)
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

  def normalized_tag_operator
    if tag_operator_column?
      normalize_operator_code(read_tag_operator, TAG_OPERATORS)
    else
      tag_filter ? '=' : '*'
    end
  end

  def operator_columns?
    self.class.operator_columns?
  end

  def tag_operator_column?
    self.class.tag_operator_column?
  end

  def show_untagged?
    return false unless self.class.column_names.include?('show_untagged')

    ActiveModel::Type::Boolean.new.cast(self[:show_untagged])
  rescue StandardError
    false
  end

  private

  def personal_visibility(user, project)
    return nil unless user&.logged? && project && self.class.can_select_display?(user, project)

    pref = preferences.find_by(user_id: user.id)
    return nil unless pref

    pref.visible?
  end

  def roles_match?(user, project)
    return false unless user.logged? && project

    user_role_ids = user.roles_for_project(project).map(&:id)
    (assigned_role_ids & user_role_ids).any?
  end

  def read_filter_operator(name)
    return '*' unless operator_columns?
    self[name].to_s.presence || '*'
  rescue StandardError
    '*'
  end

  def read_tag_operator
    return (tag_filter ? '=' : '*') unless tag_operator_column?
    self[:tag_operator].to_s.presence || (tag_filter ? '=' : '*')
  rescue StandardError
    tag_filter ? '=' : '*'
  end

  def normalize_operator_code(op, allowed)
    code = op.to_s.presence || '*'
    allowed.include?(code) ? code : '*'
  end

  def normalize_operators
    if operator_columns?
      self.status_operator = normalized_status_operator
      self.version_operator = normalized_version_operator
      self.tracker_operator = normalized_tracker_operator
    end
    if tag_operator_column?
      self.tag_operator = normalized_tag_operator
    end
    self.tag_filter = %w[= ! !*].include?(normalized_tag_operator)
  rescue StandardError
    nil
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
    return unless visibility == 'owner'

    author_id = created_by_id.presence || owner_id.presence || User.current&.id
    self.created_by_id = author_id if created_by_id.blank? && author_id.present?
    self.owner_id = author_id
    self.visible_by_default = true
  end

  def owner_visibility_only_for_author
    return unless visibility == 'owner'
    return if can_set_owner_visibility?(User.current)
    return unless will_save_change_to_visibility?
    errors.add(:visibility, :invalid)
  end

  def name_unique_within_projects
    return if name.blank?
    return if projects.empty? && tag_cloud_projects.empty?
    project_ids = projects.map(&:id).presence || tag_cloud_projects.map(&:project_id)
    return if project_ids.blank?
    conflict = self.class.joins(:tag_cloud_projects).where(tag_cloud_projects: { project_id: project_ids }).where(name: name)
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
