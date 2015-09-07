if defined?(Capybara)
	require 'action_view/helpers/sanitize_helper'

	module LinguaFranca
		module Capybara
			def visit(*args)
				# verify that the page has been completely translated
				#I18n.backend.start_looking_for_untranslated_content
				#super(*args)
				#I18n.backend.stop_looking_for_untranslated_content
				#stripped_html = ActionView::Base.full_sanitizer.sanitize(html).gsub(/\s+/, ' ').strip
				#raise Exception, "Untranslated content found: \"#{stripped_html}\"" unless stripped_html.gsub(/\s+/, '').blank?

				#I18n.backend.start_recording_html(args.first.gsub(/^https?:\/\/.*?\/(.*?)\/?$/, '\1').gsub('/', '.'))
				super(*args)
				#I18n.backend.stop_recording_html(html)
			end
		end
	end
	module Capybara
		if defined?(Capybara::Poltergeist)
			module LinguaFrancaPoltergeist
				class Driver < Capybara::Poltergeist::Driver
					include LinguaFranca::Capybara

					def server
						@server ||= Server.new(options[:port], options.fetch(:timeout) { DEFAULT_TIMEOUT })
					end
				end

  				class Server < Capybara::Poltergeist::Server
  					def send(message)
  						@@lingua_franca_email_sending ||= false
  						if @@lingua_franca_email_sending
  							return super(message)
  						end
  						result = super(message)
  						msg = JSON.parse(message)['name']
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
							gsub(/<\/head>/m, "<meta email-from='#{message.from.join(',')}'/>" + 
								"<meta email-to='#{message.to.join(',')}'/></head>")
						I18n.backend.set_html(html)
					end

					#def self.delivering_email(mail)
					#	I18n.backend.set_html(prepare_email_html(mail.parts && mail.parts.last ? 
					#		mail.parts.last.body.raw_source : mail.body.raw_source, mail.subject))
					#end

					#protected
					#	def self.prepare_email_html(html, title)
					#		html.gsub(/<!DOCTYPE html>/m, '<!DOCTYPE email>').gsub(/<title>.*?<\/title>/m, "<title>#{title}</title>")
					#	end
				end
			end
			Capybara.register_driver :lingua_franca_poltergeist do |app|
				Capybara::LinguaFrancaPoltergeist::Driver.new(app)
			end

			ActionMailer::Base.register_observer(LinguaFrancaPoltergeist::MailObserver)
			#ActionMailer::Base.register_interceptor(LinguaFrancaPoltergeist::MailObserver)
		end
		if defined?(Capybara::Selenium)
			module LinguaFrancaSelenium
				class Driver < Capybara::Selenium::Driver
					include LinguaFranca::Capybara
				end
			end
			Capybara.register_driver :lingua_franca_selenium do |app|
				Capybara::LinguaFrancaSelenium::Driver.new(app)
			end
		end
	end

	Before do |scenario|
		I18n.backend.set_test_name(scenario.title.gsub(/\s+/, '-'))
	end

	After do |scenario|
		I18n.backend.stop_recording_html
	end

end