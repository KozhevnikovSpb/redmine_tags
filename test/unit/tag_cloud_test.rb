require File.expand_path('../../test_helper', __FILE__)

class TagCloudTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :projects_trackers, :issue_statuses, :versions, :roles

  setup do
    User.stubs(:current).returns(users(:users_001))
    @project = projects(:projects_001)
    @user = users(:users_002)
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

  test 'preference overrides default visibility' do
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
end
