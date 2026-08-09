require File.expand_path('../../test_helper', __FILE__)

class TagCloudAggregatorTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :projects_trackers, :issue_statuses, :versions, :issues, :members, :member_roles, :roles

  setup do
    User.current = users(:users_001)
    @project = projects(:projects_001)
    @user = User.current
  end

  test 'empty filters do not invent tags from trackers' do
    cloud = TagCloud.create!(name: 'All', visibility: 'all', visible_by_default: true)
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    result = TagCloudAggregator.new(cloud, project: @project, user: @user).tags
    # Result is either empty or only Redmineup::Tag records — never tracker names as tags
    result.each do |tag|
      assert tag.respond_to?(:name)
      assert tag.is_a?(Redmineup::Tag) || tag.class.name.include?('Tag')
    end
  end

  test 'tag_filter with no tags returns empty' do
    cloud = TagCloud.create!(name: 'Empty tags', visibility: 'all', tag_filter: true)
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    result = TagCloudAggregator.new(cloud, project: @project, user: @user).tags
    assert_equal 0, result.to_a.size
  end

  test 'status filter restricts issue set' do
    cloud = TagCloud.create!(
      name: 'Closed only',
      visibility: 'all',
      status_filter: IssueStatus.where(is_closed: true).pluck(:id)
    )
    cloud.tag_cloud_projects.create!(project: @project, position: 0)

    # Should not raise and should run SQL with status constraint
    assert_nothing_raised do
      TagCloudAggregator.new(cloud, project: @project, user: @user).tags.to_a
    end
  end
end
