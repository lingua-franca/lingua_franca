require 'action_mailer'

module LinguaFranca
	module ActionMailer

		def send_mail(method, &block)
			@old_page_name = I18n.backend.override_page_name(method) if ENV["RAILS_ENV"] == 'test'
			options = yield
			options = default_mail_options.merge(options.is_a?(Hash) ? options : { args: options })
			args = options[:args]

			# send immediately if we are running locally, otherwise defer to sidekiq
			if ENV["RAILS_ENV"] == 'test' || ENV["RAILS_ENV"] == 'development'
				send(method, *args).deliver_now
			else
				delay.send(method, *args)
			end
			
			if ENV["RAILS_ENV"] == 'test'
				I18n.backend.init_request
				I18n.backend.stop_recording_html
				I18n.backend.end_page_name_override(@old_page_name)
			end
		end

		def default_mail_options
			{
				args: [],
				when: :now
			}
		end
	end
end

ActionMailer::Base.extend LinguaFranca::ActionMailer
