if defined?(Capybara)
	module LinguaFranca
		module Capybara
			def visit(*args)
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