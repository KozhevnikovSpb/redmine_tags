require File.expand_path('../../test_helper', __FILE__)

class TagCloudPermissionTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :projects_trackers, :issue_statuses, :versions, :roles, :members, :member_roles

  setup do
    User.stubs(:current).returns(users(:users_001))
    @project = projects(:projects_001)
    @user = users(:users_002)
    @admin = users(:users_001)
    @other = users(:users_003)
  end

  def stub_cloud_permissions(user, view: false, select: false, manage: false)
    user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(view)
    user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(select)
    user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(manage)
  end

  def create_linked_cloud(attrs)
    cloud = TagCloud.create!(attrs)
    cloud.tag_cloud_projects.create!(project: @project, position: TagCloudProject.where(project_id: @project.id).count)
    cloud
  end

  def sidebar_ids(user)
    TagCloud.sidebar_clouds_for(@project, user).map(&:id)
  end

  test 'without cloud permissions custom clouds stay hidden' do
    stub_cloud_permissions(@user)

    cloud = create_linked_cloud(name: 'Public cloud', visibility: 'all', visible_by_default: true, created_by: @user)
    own = create_linked_cloud(name: 'Mine hidden', visibility: 'owner', created_by: @user, owner: @user)

    assert_not TagCloud.can_see_custom_clouds?(@user, @project)
    assert_not TagCloud.can_view_settings_list?(@user, @project)
    assert_not TagCloud.can_select_display?(@user, @project)
    assert_not TagCloud.can_manage?(@user, @project)
    assert_not cloud.visible_for?(@user, project: @project)
    assert_not own.visible_for?(@user, project: @project)
    assert_not cloud.listed_in_settings_for?(@user, project: @project)
    assert_empty sidebar_ids(@user)
  end

  test 'view permission shows public clouds but not another authors owner cloud' do
    stub_cloud_permissions(@user, view: true)

    public_cloud = create_linked_cloud(name: 'Team cloud', visibility: 'all', visible_by_default: true, created_by: @admin)
    owner_cloud = create_linked_cloud(name: 'Admin private', visibility: 'owner', created_by: @admin, owner: @admin)

    assert TagCloud.can_see_custom_clouds?(@user, @project)
    assert TagCloud.can_view_settings_list?(@user, @project)
    assert_not TagCloud.can_select_display?(@user, @project)
    assert_not TagCloud.can_manage?(@user, @project)
    assert public_cloud.visible_for?(@user, project: @project)
    assert_not owner_cloud.visible_for?(@user, project: @project)
    assert public_cloud.listed_in_settings_for?(@user, project: @project)
    assert_not owner_cloud.listed_in_settings_for?(@user, project: @project)
    assert owner_cloud.listed_in_settings_for?(@admin, project: @project)
    assert_includes sidebar_ids(@user), public_cloud.id
    assert_not_includes sidebar_ids(@user), owner_cloud.id
  end

  test 'view permission does not list own author-only cloud in settings' do
    stub_cloud_permissions(@user, view: true)
    own = create_linked_cloud(name: 'Mine view list', visibility: 'owner', created_by: @user, owner: @user)

    assert own.visible_for?(@user, project: @project)
    assert_not own.listed_in_settings_for?(@user, project: @project)
    assert_not own.manageable_by?(@user, project: @project)
    assert_includes sidebar_ids(@user), own.id
  end

  test 'select permission cannot reveal another authors owner cloud via preference' do
    stub_cloud_permissions(@user, select: true)

    owner_cloud = create_linked_cloud(name: 'Secret', visibility: 'owner', created_by: @admin, owner: @admin)
    owner_cloud.preferences.create!(user: @user, visible: true)

    assert TagCloud.can_see_custom_clouds?(@user, @project)
    assert_not TagCloud.can_view_settings_list?(@user, @project)
    assert TagCloud.can_select_display?(@user, @project)
    assert_not owner_cloud.visible_for?(@user, project: @project)
    assert owner_cloud.visible_for?(@admin, project: @project)
    assert_not owner_cloud.listed_in_settings_for?(@user, project: @project)
    assert_not_includes sidebar_ids(@user), owner_cloud.id
  end

  test 'select permission shows public default-visible clouds and own author-only' do
    stub_cloud_permissions(@user, select: true)

    public_cloud = create_linked_cloud(name: 'Shared select', visibility: 'all', visible_by_default: true, created_by: @admin)
    hidden_default = create_linked_cloud(name: 'Hidden default', visibility: 'all', visible_by_default: false, created_by: @admin)
    own = create_linked_cloud(name: 'Mine select', visibility: 'owner', created_by: @user, owner: @user)

    assert public_cloud.visible_for?(@user, project: @project)
    assert_not hidden_default.visible_for?(@user, project: @project)
    assert own.visible_for?(@user, project: @project)
    assert_not TagCloud.can_view_settings_list?(@user, @project)
    assert_includes sidebar_ids(@user), public_cloud.id
    assert_includes sidebar_ids(@user), own.id
    assert_not_includes sidebar_ids(@user), hidden_default.id
  end

  test 'manage permission cannot change author-only clouds' do
    stub_cloud_permissions(@user, manage: true)

    owner_cloud = create_linked_cloud(name: 'Author only', visibility: 'owner', created_by: @admin, owner: @admin)
    public_cloud = create_linked_cloud(name: 'Shared', visibility: 'all', created_by: @admin)

    assert TagCloud.can_view_settings_list?(@user, @project)
    assert TagCloud.can_manage?(@user, @project)
    assert_not TagCloud.can_select_display?(@user, @project)
    assert public_cloud.manageable_by?(@user, project: @project)
    assert_not owner_cloud.manageable_by?(@user, project: @project)
    assert owner_cloud.manageable_by?(@admin, project: @project)
    assert_not owner_cloud.listed_in_settings_for?(@user, project: @project)
    assert public_cloud.listed_in_settings_for?(@user, project: @project)
  end

  test 'author sees own owner cloud in sidebar with view permission' do
    stub_cloud_permissions(@user, view: true)

    own = create_linked_cloud(name: 'Mine view', visibility: 'owner', visible_by_default: false, created_by: @user, owner: @user)

    assert own.visible_for?(@user, project: @project)
    assert_not own.listed_in_settings_for?(@user, project: @project)
    assert_not own.manageable_by?(@user, project: @project)
    assert_includes sidebar_ids(@user), own.id
  end

  test 'author sees own owner cloud in sidebar with manage permission' do
    stub_cloud_permissions(@user, manage: true)

    own = create_linked_cloud(name: 'Mine manage', visibility: 'owner', visible_by_default: false, created_by: @user, owner: @user)

    assert own.visible_for?(@user, project: @project)
    assert own.listed_in_settings_for?(@user, project: @project)
    assert_not own.manageable_by?(@user, project: @project)
    assert_includes sidebar_ids(@user), own.id
  end

  test 'author sees own owner cloud in sidebar with select permission' do
    stub_cloud_permissions(@user, select: true)

    own = create_linked_cloud(name: 'Mine select only', visibility: 'owner', visible_by_default: false, created_by: @user, owner: @user)

    assert own.visible_for?(@user, project: @project)
    assert_includes sidebar_ids(@user), own.id
  end

  test 'author can hide own owner cloud only with a personal preference' do
    stub_cloud_permissions(@user, select: true)

    own = create_linked_cloud(name: 'Mine hidden', visibility: 'owner', created_by: @user, owner: @user)
    own.preferences.create!(user: @user, visible: false)

    assert_not own.visible_for?(@user, project: @project)
    assert_not_includes sidebar_ids(@user), own.id
  end

  test 'owner visibility forces visible_by_default true' do
    cloud = TagCloud.create!(name: 'Forced default', visibility: 'owner', visible_by_default: false, created_by: @user, owner: @user)
    assert cloud.visible_by_default?
  end

  test 'author is recognized by owner_id when created_by_id is blank' do
    stub_cloud_permissions(@user, view: true)
    cloud = TagCloud.new(name: 'Owner only id', visibility: 'all', visible_by_default: true)
    cloud.created_by_id = nil
    cloud.owner_id = @user.id
    cloud.visibility = 'owner'
    cloud.save!(validate: false)
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    assert cloud.authored_by?(@user)
    assert cloud.visible_for?(@user, project: @project)
    assert_includes sidebar_ids(@user), cloud.id
  end

  test 'create path like the form assigns author ids and shows cloud to author' do
    User.stubs(:current).returns(@user)
    stub_cloud_permissions(@user, manage: true)

    cloud = TagCloud.new(name: 'From form', visibility: 'owner', visible_by_default: false)
    cloud.created_by = User.current
    assert cloud.save, cloud.errors.full_messages.inspect
    cloud.tag_cloud_projects.create!(project: @project, position: 0)
    cloud.reload

    assert_equal @user.id, cloud.created_by_id
    assert_equal @user.id, cloud.owner_id
    assert cloud.visible_by_default?
    assert cloud.authored_by?(@user)
    assert cloud.visible_for?(@user, project: @project)
    assert_not cloud.visible_for?(@other, project: @project)
    assert cloud.listed_in_settings_for?(@user, project: @project)
    assert_not cloud.manageable_by?(@user, project: @project)
    assert_includes sidebar_ids(@user), cloud.id
  end

  test 'author is recognized by created_by_id when owner_id is blank' do
    stub_cloud_permissions(@user, view: true)
    cloud = TagCloud.new(name: 'Created by only', visibility: 'all', visible_by_default: true)
    cloud.created_by_id = @user.id
    cloud.owner_id = nil
    cloud.visibility = 'owner'
    cloud.save!(validate: false)
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    assert cloud.authored_by?(@user)
    assert cloud.visible_for?(@user, project: @project)
    assert_includes sidebar_ids(@user), cloud.id
    assert_not cloud.visible_for?(@other, project: @project)
  end

  test 'settings list without project context hides author-only from non-admin' do
    stub_cloud_permissions(@user, manage: true)
    own = create_linked_cloud(name: 'Needs project', visibility: 'owner', created_by: @user, owner: @user)

    assert_not own.listed_in_settings_for?(@user)
    assert own.listed_in_settings_for?(@user, project: @project)
    assert own.listed_in_settings_for?(@admin)
  end

  test 'other member never sees author-only cloud even with all cloud permissions' do
    stub_cloud_permissions(@other, view: true, select: true, manage: true)
    own = create_linked_cloud(name: 'Private to user', visibility: 'owner', created_by: @user, owner: @user)
    own.preferences.create!(user: @other, visible: true)

    assert_not own.authored_by?(@other)
    assert_not own.visible_for?(@other, project: @project)
    assert_not own.listed_in_settings_for?(@other, project: @project)
    assert_not own.manageable_by?(@other, project: @project)
    assert_not_includes sidebar_ids(@other), own.id
  end

  test 'admin can see custom clouds without a project context' do
    assert TagCloud.can_see_custom_clouds?(@admin, nil)
    assert TagCloud.can_manage?(@admin, nil)
    assert_not TagCloud.can_see_custom_clouds?(@user, nil)
    assert_not TagCloud.can_manage?(@user, nil)
  end

  test 'preference override applies only when select permission is granted' do
    stub_cloud_permissions(@user, view: true, select: false)
    cloud = create_linked_cloud(name: 'Hidden default', visibility: 'all', visible_by_default: false, created_by: @admin)
    cloud.preferences.create!(user: @user, visible: true)

    assert_not cloud.visible_for?(@user, project: @project)

    stub_cloud_permissions(@user, view: true, select: true)
    assert cloud.visible_for?(@user, project: @project)
  end
end
