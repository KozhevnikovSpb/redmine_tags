require File.expand_path('../../test_helper', __FILE__)

class TagCloudPermissionTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :projects_trackers, :issue_statuses, :versions, :roles, :members, :member_roles

  setup do
    User.stubs(:current).returns(users(:users_001))
    @project = projects(:projects_001)
    @user = users(:users_002)
    @admin = users(:users_001)
  end

  test 'without cloud permissions custom clouds stay hidden' do
    @user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(false)
    @user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(false)
    @user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(false)

    cloud = TagCloud.create!(name: 'Public cloud', visibility: 'all', visible_by_default: true, created_by: @user)
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    assert_not TagCloud.can_see_custom_clouds?(@user, @project)
    assert_not TagCloud.can_view_settings_list?(@user, @project)
    assert_not TagCloud.can_select_display?(@user, @project)
    assert_not TagCloud.can_manage?(@user, @project)
    assert_not cloud.visible_for?(@user, project: @project)
  end

  test 'view permission shows public clouds but not another authors owner cloud' do
    @user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(true)
    @user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(false)
    @user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(false)

    public_cloud = TagCloud.create!(name: 'Team cloud', visibility: 'all', visible_by_default: true, created_by: @admin)
    public_cloud.tag_cloud_projects.create!(project: @project, position: 0)
    owner_cloud = TagCloud.create!(name: 'Admin private', visibility: 'owner', created_by: @admin, owner: @admin)
    owner_cloud.tag_cloud_projects.create!(project: @project, position: 1)

    assert TagCloud.can_see_custom_clouds?(@user, @project)
    assert TagCloud.can_view_settings_list?(@user, @project)
    assert_not TagCloud.can_select_display?(@user, @project)
    assert_not TagCloud.can_manage?(@user, @project)
    assert public_cloud.visible_for?(@user, project: @project)
    assert_not owner_cloud.visible_for?(@user, project: @project)
    assert public_cloud.listed_in_settings_for?(@user)
    assert_not owner_cloud.listed_in_settings_for?(@user)
    assert owner_cloud.listed_in_settings_for?(@admin)
  end

  test 'select permission cannot reveal another authors owner cloud via preference' do
    @user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(true)
    @user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(false)
    @user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(false)

    owner_cloud = TagCloud.create!(name: 'Secret', visibility: 'owner', created_by: @admin, owner: @admin)
    owner_cloud.tag_cloud_projects.create!(project: @project, position: 0)
    owner_cloud.preferences.create!(user: @user, visible: true)

    assert_not owner_cloud.visible_for?(@user, project: @project)
    assert owner_cloud.visible_for?(@admin, project: @project)
  end

  test 'manage permission cannot list or manage author-only clouds' do
    @user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(true)
    @user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(false)
    @user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(false)

    owner_cloud = TagCloud.create!(name: 'Author only', visibility: 'owner', created_by: @admin, owner: @admin)
    owner_cloud.tag_cloud_projects.create!(project: @project, position: 0)
    public_cloud = TagCloud.create!(name: 'Shared', visibility: 'all', created_by: @admin)
    public_cloud.tag_cloud_projects.create!(project: @project, position: 1)

    assert public_cloud.manageable_by?(@user, project: @project)
    assert_not owner_cloud.manageable_by?(@user, project: @project)
    assert owner_cloud.manageable_by?(@admin, project: @project)
    assert_not owner_cloud.listed_in_settings_for?(@user)
  end

  test 'author sees own owner cloud in sidebar when they have view permission' do
    @user.stubs(:allowed_to?).with(:view_tag_clouds, @project).returns(true)
    @user.stubs(:allowed_to?).with(:select_tag_clouds, @project).returns(false)
    @user.stubs(:allowed_to?).with(:manage_tag_clouds, @project).returns(false)

    own = TagCloud.create!(name: 'Mine', visibility: 'owner', created_by: @user, owner: @user)
    own.tag_cloud_projects.create!(project: @project, position: 0)

    assert own.visible_for?(@user, project: @project)
    assert_not own.listed_in_settings_for?(@user)
    assert_not own.manageable_by?(@user, project: @project)
  end
end
