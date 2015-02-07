Rails.application.routes.draw do
    root 'application#home', :as => :home
    post 'login' => 'application#login', :as => :login
    patch 'logout' => 'application#logout', :as => :logout
    match 'translate' => 'application#translate_toggle', :as => :translate_toggle, via: [:get, :post]
    match 'save_post' => 'application#save_post', :as => :save_post, via: [:post, :patch]
    get 'translate_post/:id' => 'application#translate_post', :as => :translate_post
end
