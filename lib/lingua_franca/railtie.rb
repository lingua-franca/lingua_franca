module LinguaFranca
  class Railtie < ::Rails::Railtie
    initializer "lingua_franca.add_delivery_method" do
      ::ActiveSupport.on_load :action_mailer do
        ::ActionMailer::Base.add_delivery_method :lingua_franca, LinguaFranca::TestMailer, location: ::Rails.root.join("tmp", "lingua_franca")
      end
    end
  end
end
