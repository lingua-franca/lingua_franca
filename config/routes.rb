Rails.application.routes.draw do
  get "translations" => "translations#index", :as => :translations_index
  get "translations/:locale" => "translations#locale", :as => :translate_locale_index
  post "translations/:locale/store" => "translations#save_key", :as => :translate_save_key
end
