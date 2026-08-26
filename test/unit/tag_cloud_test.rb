require File.expand_path('../../test_helper', __FILE__)

class TagCloudTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :projects_trackers, :issue_statuses, :versions, :roles, :members, :member_roles

  setup do
    User.stubs(:current).returns(users(:users_001))
    @project = projects(:projects_001)
    @user = users(:users_002)
    @admin = users(:users_001)
  end

  def stub_cloud_permissions(user, view: false, select: false, manage: false)
    user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(view)
    user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(select)
    user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(manage)
  end

  test 'serializes filters as integer arrays' do
    cloud = TagCloud.new(name: 'Filtered', status_filter: ['1', '', '1'])
    cloud.valid?
    assert_equal [1], cloud.status_filter
  end

  test 'name uniqueness is scoped to projects' do
    cloud1 = TagCloud.create!(name: 'Shared Name', visibility: 'all')
    cloud1.tag_cloud_projects.create!(project: @project, position: 0)

    cloud2 = TagCloud.new(name: 'Shared Name', visibility: 'all')
    cloud2.tag_cloud_projects.build(project: @project, position: 1)
    assert_not cloud2.valid?
    assert cloud2.errors[:name].present?
  end

  test 'name is limited to 100 characters' do
    cloud = TagCloud.new(name: 'a' * TagCloud::NAME_MAX_LENGTH, visibility: 'all')
    assert cloud.valid?, cloud.errors.full_messages.inspect

    cloud.name = 'a' * (TagCloud::NAME_MAX_LENGTH + 1)
    assert_not cloud.valid?
    assert cloud.errors[:name].present?
  end

  test 'preference overrides default visibility' do
    stub_cloud_permissions(@user, view: true, select: true)
    cloud = TagCloud.create!(name: 'Hidden', visible_by_default: false, visibility: 'all')
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    assert_not cloud.visible_for?(@user, project: @project)
    cloud.preferences.create!(user: @user, visible: true)
    assert cloud.visible_for?(@user, project: @project)
  end

  test 'for_project orders by join position' do
    c1 = TagCloud.create!(name: 'B', visibility: 'all')
    c2 = TagCloud.create!(name: 'A', visibility: 'all')
    c1.tag_cloud_projects.create!(project: @project, position: 1)
    c2.tag_cloud_projects.create!(project: @project, position: 0)

    ordered = TagCloud.for_project(@project).to_a
    assert_equal [c2.id, c1.id], ordered.map(&:id)
  end

  test 'cloud without project link is not returned by for_project' do
    TagCloud.create!(name: 'Orphan', visibility: 'all')
    assert_empty TagCloud.for_project(@project)
  end

  test 'inherited_for includes ancestor clouds with include_subprojects' do
    child = Project.where.not(parent_id: nil).first
    skip 'Need a subproject fixture' unless child

    parent = child.parent
    inherited = TagCloud.create!(name: 'Root cloud', visibility: 'all', include_subprojects: true)
    inherited.tag_cloud_projects.create!(project: parent, position: 0)

    hidden = TagCloud.create!(name: 'Parent only', visibility: 'all', include_subprojects: false)
    hidden.tag_cloud_projects.create!(project: parent, position: 1)

    local = TagCloud.create!(name: 'Child cloud', visibility: 'all')
    local.tag_cloud_projects.create!(project: child, position: 0)

    ids = TagCloud.inherited_for(child).map(&:id)
    assert_includes ids, inherited.id
    assert_not_includes ids, hidden.id
    assert_not_includes ids, local.id
    assert inherited.inherited_in?(child)
    assert_not local.inherited_in?(child)

    sidebar_ids = TagCloud.for_sidebar(child).map(&:id)
    assert_equal inherited.id, sidebar_ids.first
    assert_includes sidebar_ids, local.id
    assert sidebar_ids.index(inherited.id) < sidebar_ids.index(local.id)
  end

  test 'visibility owner only owner sees cloud' do
    stub_cloud_permissions(@user, view: true)
    cloud = TagCloud.create!(
      name: 'Owner cloud',
      visibility: 'owner',
      owner: @admin,
      created_by: @admin,
      visible_by_default: true
    )
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    assert cloud.visible_for?(@admin, project: @project)
    assert_not cloud.visible_for?(@user, project: @project)
  end

  test 'visibility roles requires matching project role' do
    stub_cloud_permissions(@user, view: true)
    role = roles(:roles_001)
    cloud = TagCloud.new(name: 'Roles cloud', visibility: 'roles', visible_by_default: true)
    cloud.role_ids = [role.id]
    assert cloud.save, cloud.errors.full_messages.inspect
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    member_roles = @user.roles_for_project(@project).map(&:id)
    if member_roles.include?(role.id)
      assert cloud.visible_for?(@user, project: @project)
    else
      assert_not cloud.visible_for?(@user, project: @project)
    end

    assert_not cloud.visible_for?(User.anonymous, project: @project)
  end

  test 'visibility roles invalid without roles' do
    cloud = TagCloud.new(name: 'No roles', visibility: 'roles')
    assert_not cloud.valid?
    assert cloud.errors[:roles].present?
  end

  test 'owner is set automatically when visibility is owner' do
    User.stubs(:current).returns(@admin)
    cloud = TagCloud.new(name: 'Auto owner', visibility: 'owner')
    cloud.valid?
    assert_equal @admin.id, cloud.owner_id
  end

  test 'owner follows created_by not current user' do
    User.stubs(:current).returns(@user)
    cloud = TagCloud.new(name: 'Author owner', visibility: 'owner', created_by: @admin)
    cloud.valid?
    assert_equal @admin.id, cloud.owner_id
    assert_equal @admin, cloud.visibility_author
  end

  test 'non author cannot switch visibility to owner' do
    User.stubs(:current).returns(@admin)
    cloud = TagCloud.create!(name: 'Admin cloud', visibility: 'all', created_by: @admin)
    User.stubs(:current).returns(@user)
    cloud.visibility = 'owner'
    assert_not cloud.valid?
    assert cloud.errors[:visibility].present?
  end

  test 'tag_filter association stores tag ids' do
    cloud = TagCloud.create!(name: 'With tags', visibility: 'all', tag_filter: true)
    cloud.tag_cloud_projects.create!(project: @project, position: 0)
    assert_equal true, cloud.tag_filter
    assert_equal [], cloud.tag_ids
  end

  test 'operators match Redmine 7 Issue Query filter types' do
    assert_equal %w[o = ! ev !ev cf c *], TagCloud::STATUS_OPERATORS
    assert_equal %w[= ! ev !ev cf !* *], TagCloud::VERSION_OPERATORS
    assert_equal %w[= ! ev !ev cf *], TagCloud::TRACKER_OPERATORS
    %w[= ! ev !ev cf].each do |op|
      assert_includes TagCloud::VALUE_OPERATORS, op
    end
  end
end
