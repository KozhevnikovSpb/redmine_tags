class TagCloudsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize
  before_action :find_tag_cloud, only: %i[edit update destroy]

  def index
    @tag_clouds = TagCloud.for_project(@project).to_a
  end

  def new
    @tag_cloud = TagCloud.new(
      visible_by_default: true,
      visibility: 'all',
      tag_filter: false,
      include_subprojects: false
    )
    load_filter_options
  end

  def create
    @tag_cloud = TagCloud.new(tag_cloud_params)
    @tag_cloud.created_by = User.current
    @tag_cloud.visibility ||= 'all'

    TagCloud.transaction do
      @tag_cloud.save!
      position = next_position
      @tag_cloud.tag_cloud_projects.create!(project: @project, position: position)
    end

    redirect_to settings_project_path(@project, tab: 'tags'), notice: l(:notice_tag_cloud_created)
  rescue ActiveRecord::RecordInvalid
    load_filter_options
    render :new, status: :unprocessable_entity
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
    # Unlink from this project; destroy cloud only if no other projects remain
    link = @tag_cloud.tag_cloud_projects.find_by(project_id: @project.id)
    link&.destroy
    @tag_cloud.destroy! if @tag_cloud.tag_cloud_projects.reload.empty?

    redirect_to settings_project_path(@project, tab: 'tags'), notice: l(:notice_tag_cloud_deleted)
  end

  def reorder
    ids = Array(params[:tag_cloud_ids]).map(&:to_i).reject(&:zero?)
    links = @project.tag_cloud_projects.where(tag_cloud_id: ids).index_by(&:tag_cloud_id)

    TagCloudProject.transaction do
      ids.each_with_index do |id, index|
        link = links[id]
        next unless link

        link.update!(position: index) if link.position != index
      end
    end

    head :no_content
  end

  private

  def find_tag_cloud
    @tag_cloud = TagCloud.for_project(@project).find(params[:id])
  end

  def next_position
    (@project.tag_cloud_projects.maximum(:position) || -1) + 1
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
      :visibility,
      :tag_filter,
      :include_subprojects,
      status_filter: [],
      version_filter: [],
      tracker_filter: []
    )
  end
end
