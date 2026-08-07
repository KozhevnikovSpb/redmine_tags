class TagCloudsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize
  before_action :ensure_system_cloud
  before_action :find_tag_cloud, only: %i[edit update destroy]

  def index
    @tag_clouds = @project.tag_clouds.unscoped.order(:position, :id)
  end

  def new
    @tag_cloud = @project.tag_clouds.build(
      visible_by_default: true,
      is_system: false,
      position: next_position
    )
    load_filter_options
  end

  def create
    @tag_cloud = @project.tag_clouds.build(tag_cloud_params)
    @tag_cloud.created_by = User.current
    @tag_cloud.position = next_position if @tag_cloud.position.blank?

    if @tag_cloud.save
      redirect_to settings_project_path(@project, tab: 'tags'), notice: l(:notice_tag_cloud_created)
    else
      load_filter_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_filter_options
  end

  def update
    if @tag_cloud.update(tag_cloud_params)
      redirect_to settings_project_path(@project, tab: 'tags'), notice: l(:notice_tag_cloud_updated)
    else
      load_filter_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @tag_cloud.is_system?
      redirect_to settings_project_path(@project, tab: 'tags'), alert: l(:alert_cannot_delete_system_cloud)
      return
    end

    @tag_cloud.destroy!
    redirect_to settings_project_path(@project, tab: 'tags'), notice: l(:notice_tag_cloud_deleted)
  end

  def reorder
    ids = Array(params[:tag_cloud_ids]).map(&:to_i)
    clouds = @project.tag_clouds.unscoped.where(id: ids).index_by(&:id)

    # System cloud always position 0; custom clouds follow in given order
    system = @project.tag_clouds.unscoped.find_by(is_system: true)
    ordered_ids = ids.dup
    if system
      ordered_ids.delete(system.id)
      ordered_ids.unshift(system.id)
    end

    TagCloud.transaction do
      ordered_ids.each_with_index do |id, index|
        cloud = clouds[id] || (system if system && system.id == id)
        next unless cloud

        cloud.update!(position: index)
      end
    end

    head :no_content
  end

  private

  def find_tag_cloud
    @tag_cloud = @project.tag_clouds.unscoped.find(params[:id])
  end

  def ensure_system_cloud
    TagCloud.ensure_system_cloud(@project)
  end

  def next_position
    (@project.tag_clouds.unscoped.maximum(:position) || 0) + 1
  end

  def load_filter_options
    @statuses = IssueStatus.sorted
    @trackers = @project.trackers.sorted
    @versions = @project.versions.sorted
  end

  def tag_cloud_params
    params.require(:tag_cloud).permit(
      :name,
      :visible_by_default,
      :position,
      status_filter: [],
      version_filter: [],
      tracker_filter: []
    )
  end
end
