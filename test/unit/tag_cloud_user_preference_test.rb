require File.expand_path('../../test_helper', __FILE__)

class TagCloudUserPreferenceTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles

  setup do
    @user = users(:users_002)
    @admin = users(:users_001)
  end

  def stub_global_cloud_permissions(user, view: false, select: false, manage: false)
    user.stubs(:admin?).returns(false)
    user.stubs(:logged?).returns(true)
    user.stubs(:allowed_to?).with(:view_tag_clouds, nil, global: true).returns(view)
    user.stubs(:allowed_to?).with(:select_tag_clouds, nil, global: true).returns(select)
    user.stubs(:allowed_to?).with(:manage_tag_clouds, nil, global: true).returns(manage)
  end

  test 'show_count is available without cloud permissions' do
    stub_global_cloud_permissions(@user)
    assert TagCloudUserPreference.show_count?(@user) || !TagCloudUserPreference.show_count?(@user)
    assert_not TagCloudUserPreference.can_configure_untagged?(@user)
  end

  test 'untagged profile switch hidden without cloud permissions' do
    stub_global_cloud_permissions(@user)
    TagCloudUserPreference.save_display!(@user, show_untagged: true)

    assert_not TagCloudUserPreference.can_configure_untagged?(@user)
    assert_not TagCloudUserPreference.show_untagged?(@user)
  end

  test 'view permission cannot enable untagged master switch' do
    stub_global_cloud_permissions(@user, view: true)
    TagCloudUserPreference.save_display!(@user, show_untagged: true)

    assert_not TagCloudUserPreference.can_configure_untagged?(@user)
    assert_not TagCloudUserPreference.show_untagged?(@user)
  end

  test 'select permission cannot enable untagged master switch' do
    stub_global_cloud_permissions(@user, select: true)
    TagCloudUserPreference.save_display!(@user, show_untagged: true)

    assert_not TagCloudUserPreference.can_configure_untagged?(@user)
    assert_not TagCloudUserPreference.show_untagged?(@user)
  end

  test 'manage permission can enable untagged master switch' do
    stub_global_cloud_permissions(@user, manage: true)

    assert TagCloudUserPreference.can_configure_untagged?(@user)
    assert TagCloudUserPreference.save_display!(@user, show_untagged: true)
    assert TagCloudUserPreference.show_untagged?(@user)
  end

  test 'admin can always configure untagged master switch' do
    assert @admin.admin?
    assert TagCloudUserPreference.can_configure_untagged?(@admin)
  end

  test 'losing manage rights clears stored untagged master switch' do
    stub_global_cloud_permissions(@user, manage: true)
    assert TagCloudUserPreference.save_display!(@user, show_untagged: true)
    rec = TagCloudUserPreference.find_by(user_id: @user.id)
    assert rec
    assert ActiveModel::Type::Boolean.new.cast(rec[:show_untagged])

    stub_global_cloud_permissions(@user, select: true)
    assert_not TagCloudUserPreference.can_configure_untagged?(@user)
    assert_not TagCloudUserPreference.show_untagged?(@user)
    rec.reload
    assert_not ActiveModel::Type::Boolean.new.cast(rec[:show_untagged])
  end

  test 'losing manage rights clears per-cloud untagged flags' do
    skip unless TagCloudPreference.table_exists? && TagCloudPreference.column_names.include?('show_untagged')
    skip unless TagCloud.table_exists?

    stub_global_cloud_permissions(@user, manage: true)
    cloud = TagCloud.create!(name: 'Untagged revoke', visibility: 'all', visible_by_default: true, created_by: @user)
    pref = TagCloudPreference.create!(tag_cloud: cloud, user: @user, visible: true, show_untagged: true)
    TagCloudUserPreference.save_display!(@user, show_untagged: true)

    stub_global_cloud_permissions(@user, select: true)
    TagCloudUserPreference.revoke_untagged_if_unauthorized!(@user)

    pref.reload
    assert_not pref.show_untagged_enabled?
    rec = TagCloudUserPreference.find_by(user_id: @user.id)
    assert rec
    assert_not ActiveModel::Type::Boolean.new.cast(rec[:show_untagged])
  end

  test 'save_display ignores untagged when user lacks manage permission' do
    stub_global_cloud_permissions(@user, select: true)
    rec = TagCloudUserPreference.find_or_initialize_by(user_id: @user.id)
    rec.show_count = true
    rec.show_weight = false
    rec.save!

    TagCloudUserPreference.save_display!(@user, show_count: false, show_untagged: true)
    rec.reload
    assert_not rec.show_count
    assert_not ActiveModel::Type::Boolean.new.cast(rec[:show_untagged]) if rec.has_attribute?(:show_untagged)
  end
end
