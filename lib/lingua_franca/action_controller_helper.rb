require "action_controller"
require "http_accept_language"

class LinguaFrancaApplicationController < ActionController::Base
	before_filter :capture_page_info

	def capture_page_info
		locale_status = (I18n.backend.set_locale request.host, params)
		if locale_status.nil?
			locale_not_detected!
		elsif !locale_status
			case I18n.config.language_detection_method
			when I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM
				locale = params[I18n.config.language_url_param.to_sym]
			when I18n::Config::DETECT_LANGUAGE_FROM_SUBDOMAIN
				locale = get_locale(host)
			end
			
			if I18n.locale_available?(locale)
				locale_not_enabled!(locale)
			else
				locale_not_available!(locale)
			end
		elsif I18n.config.language_detection_method == I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM
			session[:current_locale] = I18n.locale
		end

		I18n.config.translation_model ||= TranslationRecord
		I18n.backend.init_page(request, params)

		@translatable = !I18n.backend.testing_started
	end

	def locale_not_available!(locale = nil)
		set_default_locale
		raise AbstractController::ActionNotFound
	end

	def locale_not_enabled!(locale = nil)
		set_default_locale
		raise AbstractController::ActionNotFound
	end

	def locale_not_detected!
		default_locale = set_default_locale
		if !@lingua_franca_halt_redirection && I18n.config.language_detection_method == I18n::Config::DETECT_LANGUAGE_FROM_SUBDOMAIN
			redirect_to subdomain: default_locale
		end
	end

	def set_default_locale
		if I18n.config.language_detection_method == I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM && session[:current_locale].present?
			return (I18n.locale = session[:current_locale])
		end
		I18n.locale = http_accept_language.compatible_language_from(I18n.backend.enabled_locales)
	end

	def can_translate
		return true
	end

	def halt_redirection!
		@@lingua_franca_halt_redirection = true
	end
end
