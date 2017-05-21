require 'mail'
require 'mail/check_delivery_params'
require 'action_mailer'

module LinguaFranca
  class TestMailer < Mail::TestMailer

    def deliver!(mail)
      LinguaFranca.capture_mail(mail) if LinguaFranca.recording?
      super(mail)
    end
    
  end
end
