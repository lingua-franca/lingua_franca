Rails.application.routes.draw do
  get "translations" => "translations#index", :as => :translations_index
  get "translations/:locale" => "translations#locale", :as => :translate_locale_index
  get "translations/examples/:key/:id" => "translations#example_page", :key => /[A-Za-z0-9_\.]+/, :as => :translate_example_page
  match "translations/:locale/store" => "translations#save_key", :as => :translate_save_key, via: [:get, :post]
end
