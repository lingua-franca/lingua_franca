Rails.application.routes.draw do
  # get "translations" => "translations#index", :as => :translations_index
  # get "translations/:locale" => "translations#locale", :as => :translate_locale_index
  # get "translations/examples/:key/:page_name" => "translations#example_page", :key => /[A-Za-z0-9_\.]+/, :as => :translate_example_page, :page_name => /.+/
  # post "translations/:locale/store" => "translations#save_key", :as => :translate_save_key
  if Rails.env.test?
    get '__lingua_franca_capture' => 'lingua_franca_capture#capture', as: :lingua_franca_capture
  end
end
