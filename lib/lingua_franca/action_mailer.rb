require 'action_mailer'

class ActionMailer::Base
	# def lingua_franca_mail(headers = {}, &block)
	# 	@page_name = headers[:subject]
	# 	super_mail(headers, &block)
	# end

	# alias_method :super_mail, :mail
	# alias_method :mail, :lingua_franca_mail

	#def deliver_now(*args)
	#	raise "Do not call deliver_now directly, use send_mail instead"
	#end

	#def deliver_later(*args)
		#raise "Do not call deliver_later directly, use send_mail instead"
	#end

	# protected
	# 	def prepare_email_html(html)
	# 		html.gsub(/<!DOCTYPE html>/m, '<!DOCTYPE email>').gsub(/<title>.*?<\/title>/m, "<title>#{@page_name}</title>")
	# 	end
end

module LinguaFranca
	module ActionMailer

		def send_mail(method, &block)
			@old_page_name = I18n.backend.override_page_name(method) if ENV["RAILS_ENV"] == 'test'
			args = default_mail_options.merge(yield)

			send(method, args[:args]).send("deliver_#{args[:when].to_s}")
			
			if ENV["RAILS_ENV"] == 'test'
				I18n.backend.init_request
				I18n.backend.stop_recording_html
				I18n.backend.end_page_name_override(@old_page_name)
			end
		end

		def default_mail_options
			{
				:args => {},
				:when => :now
			}
		end
	end
end

ActionMailer::Base.extend LinguaFranca::ActionMailer
