if defined?(Capybara)
	require 'action_view/helpers/sanitize_helper'

	module LinguaFranca
		module Capybara
			def visit(*args)
				# verify that the page has been completely translated
				I18n.backend.start_looking_for_untranslated_content
				super(*args)
				I18n.backend.stop_looking_for_untranslated_content
				stripped_html = ActionView::Base.full_sanitizer.sanitize(html).gsub(/\s+/, ' ').strip
				raise Exception, "Untranslated content found: \"#{stripped_html}\"" unless stripped_html.gsub(/\s+/, '').blank?
				
				I18n.backend.start_recording_html
				super(*args)
				I18n.backend.stop_recording_html(html)
			end
		end
	end
	module Capybara
		if defined?(Capybara::Poltergeist)
			module LinguaFrancaPoltergeist
				class Driver < Capybara::Poltergeist::Driver
					include LinguaFranca::Capybara
				end
			end
			Capybara.register_driver :lingua_franca_poltergeist do |app|
				Capybara::LinguaFrancaPoltergeist::Driver.new(app)
			end
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
else
end