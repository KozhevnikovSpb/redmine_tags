RedmineApp::Application.routes.draw do
  match 'auto_completes/redmine_tags' => 'auto_completes#redmine_tags', via: :get, as: 'auto_complete_redmine_tags'
  match '/tags/context_menu', to: 'tags#context_menu', as: 'tags_context_menu', via: %i[get post]
  match '/tags', controller: 'tags', action: 'destroy', via: :delete

  resources :tags, only: %i[edit update] do
    collection do
      post :merge
      get :context_menu
      get :merge
    end
  end

  get :edit_issue_tags, to: 'issue_tags#edit'
  post :update_issue_tags, to: 'issue_tags#update'

  resources :projects do
    resources :tag_clouds, only: %i[index new create edit update destroy] do
      collection do
        post :reorder
      end
      resource :preference,
               only: [],
               controller: 'tag_cloud_preferences' do
        post :toggle
      end
    end

    # Bulk preferences modal (Select visible tag clouds)
    resource :tag_cloud_preferences,
             only: %i[edit update],
             controller: 'tag_cloud_preferences'
  end
end
