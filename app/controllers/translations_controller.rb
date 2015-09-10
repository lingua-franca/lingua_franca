require 'diffy'

class TranslationsController < ::ApplicationController
	before_filter :require_authorization

	def index
		@locales = Array.new
		I18n.available_locales.each { |locale|
			@locales << get_locale_info(locale)
		}

		# sort them by their name in the current locale
		@locales.sort! { |a, b| a[:name] <=> b[:name] }

		@enabled_locales = @locales.select { |locale| locale[:is_enabled] }
		@inprogress_locales = @locales.select { |locale| !locale[:is_enabled] && locale[:completion] > 0 }
		@disabled_locales = @locales.select { |locale| !locale[:is_enabled] && locale[:completion] <= 0 }
	end

	def locale
		I18n.backend.load_translations # make sure the translations are up to date
		
		@locale = get_locale_info(params[:locale])
		@translation_info = nil
		@page = nil
		@concern = nil

		if params.has_key?(:page)
			@translation_info = I18n.backend.translation_info_for_page(@page = params[:page], params[:locale])
		elsif params.has_key?(:concern)
			@translation_info = I18n.backend.translation_info_for_concern(@concern = params[:concern], params[:locale])
		end

		# default to translation info
		@translation_info ||= I18n.backend.undefined_translation_info(params[:locale])

		@pages = I18n.backend.pages
		@concerns = I18n.backend.concerns
	end

	def save_key
		data = {}
		save_data = {}
		params[:data].each { |key, value|
			if params.has_key?(:remove) && params[:remove].has_key?(key)
				# set the key up for removal, don't worry, we'll catch it in our
				# validate method if it shouldn't be removed
				save_data[key] = value = nil
			else
				# get rid of these spaces, they are put in around variables
				value = value.gsub('&nbsp;', ' ')
				if params.has_key?(:index) && params[:index]
					# this is actually an array
					save_data[key] = I18n.t(key, :locale => params[:locale], :resolve => false)
					save_data[key][params[:index].to_i] = value
				else
					save_data[key] = value
				end
			end

			# make sure this key looks valid
			if (error = I18n.backend.validate_translation(params[:locale], key, value))
				# for whatever reason, it didn't look right, so quit now
				render json: { :error_message => I18n.t(error), :status => 422 }
				return
			end
		}
		I18n.backend.add_translation(params[:locale], I18n.backend.expand_data(save_data))
		params[:data].each { |key, value|
			data[key] = I18n.t(key, :locale => params[:locale], :resolve => false)
		}
		render json: { :locale => params[:locale], :data => data }
	end

	def example_page
		html = File.read(File.join(I18n.config.html_records_dir, "#{params[:page_name]}.html"))
		@translatable = false
		matches = /^\s*<!DOCTYPE email>(.*<body.*?>)(.*)(<\/body>.*)$/m.match(html)
		if matches
			content = render_to_string 'email', :layout => false, :locals => {:content => matches[2]}
			html = '<!DOCTYPE html>' + matches[1] + content + matches[3]
			html = html.gsub('<html', '<html data-lingua-franca-example="email"')
		else
			html = html.gsub('</body>',
				'<div id="lingua-franca-window-caption"><div class="window-tab"><span class="lingua-franca-title"></span></div><i class="window-minimize"></i><i class="window-maximize"></i><i class="window-close"></i><div class="window-url-bar"><i class="window-back"></i><i class="window-forward"></i><div class="url-bar">https://www.bikebike.org</div></div></div>' + 
				#'<div id="lingua-franca-description"><span class="lingua-franca-description"></span></div>' +
				'</body>')
			html = html.gsub('<html', '<html data-lingua-franca-example="html"')
		end
		html = html.gsub('</body>', '<div id="lingua-franca-pointer" data-i18n-example-key="' + params[:key] + '"></div><script src="/assets/lingua-franca-example.js"></script></body>')
		render html: html.html_safe
	end

	protected
		def get_locale_info(locale)
			{
				:code => locale,
				:name => I18n.t("languages.#{locale}"),
				:url  => url_for(translate_locale_index_path(locale)),
				:is_enabled => I18n.backend.locale_enabled?(locale),
				:completion => I18n.backend.get_language_completion(locale)
			}
		end

		def require_authorization
			raise AbstractController::ActionNotFound unless I18n.backend.can_translate?
		end
end
