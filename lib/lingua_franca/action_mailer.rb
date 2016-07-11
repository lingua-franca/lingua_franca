require 'action_mailer'

module LinguaFranca
	module ActionMailer

		def send_mail(method, &block)
			@old_page_name = I18n.backend.override_page_name(method) if ENV["RAILS_ENV"] == 'test'
			options = yield
			options = default_mail_options.merge(options.is_a?(Hash) ? options : { args: options })
			args = []

			(options[:args].is_a?(Array) ? options[:args] : [options[:args]]).each do | arg |
				if arg.is_a?(User) || arg.is_a?(Comment) || arg.is_a?(Workshop) || arg.is_a?(Conference) || arg.is_a?(Workshop) || arg.is_a?(ConferenceRegistration) || arg.is_a?(EmailConfirmation)
					arg = arg.id
				elsif arg.is_a?(ActionDispatch::Request)
					request = {
						'remote_ip'    => arg.remote_ip,
						'uuid'         => arg.uuid,
						'original_url' => arg.original_url,
						'env'          => Hash.new
					}
					arg.env.each do | key, value |
						request['env'][key.to_s] = value.to_s
					end
					arg = request
				end
				raise "Argument must be a string, number, boolean, array, or hash but received #{arg.class.name}" unless arg.is_a?(NilClass) || arg.is_a?(String) || arg.is_a?(Integer) || arg.is_a?(Float) || arg.is_a?(TrueClass) || arg.is_a?(FalseClass) || arg.is_a?(Array) || arg.is_a?(Hash)
				args << arg
			end

			# send immediately if we are running locally, otherwise defer to sidekiq
			if ENV["RAILS_ENV"] == 'test' || ENV["RAILS_ENV"] == 'development'
				send(method, *args).deliver_now!
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
