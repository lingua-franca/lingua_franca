if defined?(Capybara)
	require 'action_view/helpers/sanitize_helper'

	# module LinguaFranca
	# 	module Capybara
	# 		def visit(*args)
	# 			# verify that the page has been completely translated
	# 			#I18n.backend.start_looking_for_untranslated_content
	# 			#super(*args)
	# 			#I18n.backend.stop_looking_for_untranslated_content
	# 			#stripped_html = ActionView::Base.full_sanitizer.sanitize(html).gsub(/\s+/, ' ').strip
	# 			#raise Exception, "Untranslated content found: \"#{stripped_html}\"" unless stripped_html.gsub(/\s+/, '').blank?

	# 			#I18n.backend.start_recording_html(args.first.gsub(/^https?:\/\/.*?\/(.*?)\/?$/, '\1').gsub('/', '.'))
	# 			super(*args)
	# 			#I18n.backend.stop_recording_html(html)
	# 		end
	# 	end
	# end
	module Capybara
		if defined?(Capybara::Poltergeist)
			module LinguaFrancaPoltergeist
				class Driver < Capybara::Poltergeist::Driver
					# include LinguaFranca::Capybara

					def server
						@server ||= Server.new(options[:port], options.fetch(:timeout) { DEFAULT_TIMEOUT })
					end
				end

  				class Server < Capybara::Poltergeist::Server
  					def fsend(message)
						I18n.backend.stop_recording_html
  						
  						@@lingua_franca_email_sending ||= false
  						if @@lingua_franca_email_sending
  							return super(message)
  						end
  						result = super(message)
  						msg = JSON.parse(message.message)['name']
  						if msg != 'current_url' && msg != 'body'
  							html = JSON.load(send(JSON.dump({'name' => 'body'})))['response'].to_s

  							# see if the result was actually empty
  							if html.gsub(/<\/?(html|head|body)>/, '').strip.length > 0
  								I18n.backend.set_html(html)
  							end
	  					end
	  					result
  					end
				end

				class MailObserver
					def self.delivered_email(message)
						html = (message.parts && message.parts.last ? message.parts.last.body.raw_source : message.body.raw_source).
							gsub(/<!DOCTYPE html>/m, '<!DOCTYPE email>').
							gsub(/<title>.*?<\/title>/m, "<title>#{CGI.escapeHTML(message.subject)}</title>").
							gsub(/<\/head>/m, "<meta name=\"email-from\" content='#{message.from.join(',')}'/>" + 
								"<meta name=\"email-to\" content='#{message.to.join(',')}'/></head>")
						I18n.backend.set_html(html)
					end
				end
			end
			Capybara.register_driver :lingua_franca_poltergeist do |app|
				Capybara::LinguaFrancaPoltergeist::Driver.new(app)
			end

			ActionMailer::Base.register_observer(LinguaFrancaPoltergeist::MailObserver)
		end
	end

	Before do |scenario|
		I18n.backend.set_test_name(scenario.name.gsub(/\s+/, '-'))
	end

	After do |scenario|
		I18n.backend.stop_recording_html
	end

end