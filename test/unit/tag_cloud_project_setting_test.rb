require File.expand_path('../../test_helper', __FILE__)

class TagCloudProjectSettingTest < ActiveSupport::TestCase
  fixtures :projects, :users

  setup do
    @project = projects(:projects_001)
    @user = users(:users_002)
    User.stubs(:current).returns(@user)
  end

  test 'system cloud is visible by default when no project setting exists' do
    skip unless TagCloudProjectSetting.table_exists?

    TagCloudProjectSetting.where(project_id: @project.id).delete_all
    assert TagCloudProjectSetting.system_visible_by_default?(@project)
    assert TagCloudPreference.system_visible_for?(@user, @project)
  end

  test 'hiding system cloud at project level hides it for users without personal override' do
    skip unless TagCloudProjectSetting.table_exists?

    TagCloudProjectSetting.set_system_visible_by_default!(@project, false)
    assert_not TagCloudProjectSetting.system_visible_by_default?(@project)
    assert_not TagCloudPreference.system_visible_for?(@user, @project)
  end

  test 'user with select can show system cloud when project default is hidden' do
    skip unless TagCloudProjectSetting.table_exists?

    TagCloudProjectSetting.set_system_visible_by_default!(@project, false)
    TagCloudPreference.set_system_visible!(@user, @project, true)
    assert TagCloudPreference.system_visible_for?(@user, @project)
  end

  test 'reset personal prefs follows project default' do
    skip unless TagCloudProjectSetting.table_exists?

    TagCloudProjectSetting.set_system_visible_by_default!(@project, false)
    TagCloudPreference.set_system_visible!(@user, @project, true)
    TagCloudPreference.reset_for_user!(@user, @project)
    assert_not TagCloudPreference.system_visible_for?(@user, @project)
  end

  test 'visible by default forces include_subprojects off' do
    skip unless TagCloudProjectSetting.table_exists?
    skip unless TagCloudProjectSetting.include_subprojects_column?

    TagCloudProjectSetting.update_system!(@project, visible: true, include_subprojects: true)
    assert TagCloudProjectSetting.local_visible_by_default?(@project)
    assert_not TagCloudProjectSetting.local_include_subprojects?(@project)
  end

  test 'parent hide with subprojects locks descendants' do
    skip unless TagCloudProjectSetting.table_exists?
    skip unless TagCloudProjectSetting.include_subprojects_column?

    child = projects(:projects_003)
    child.stubs(:ancestors).returns([@project])

    TagCloudProjectSetting.update_system!(@project, visible: false, include_subprojects: true)
    assert TagCloudProjectSetting.locked_by_ancestor?(child)
    assert_not TagCloudProjectSetting.system_visible_by_default?(child)
  end

  test 'parent hide without subprojects does not lock descendants' do
    skip unless TagCloudProjectSetting.table_exists?
    skip unless TagCloudProjectSetting.include_subprojects_column?

    child = projects(:projects_003)
    child.stubs(:ancestors).returns([@project])

    TagCloudProjectSetting.update_system!(@project, visible: false, include_subprojects: false)
    assert_not TagCloudProjectSetting.locked_by_ancestor?(child)
    assert TagCloudProjectSetting.system_visible_by_default?(child)
  end
end
