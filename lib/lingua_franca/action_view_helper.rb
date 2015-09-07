require "action_view"

module LinguaFrancaHelper
	def _(*args, &block)
		inner_html = nil
		if block_given?
			key = args.first
			
			translations = Array.new

			if key.is_a?(Array)
				key.each { |k|
					args2 = args
					args[0] = k
					translations << I18n.backend._(*args2)
				}
			else
				translations << I18n.backend._(*args)
			end
			inner_html = send(:capture, *translations, &block)
		end
		I18n.backend.wrap(inner_html || I18n.backend._(*args), *args, &block).html_safe
	end

	# mark contents as exempt from translation
	def _!(contents = nil, &block)
		I18n.backend._!(contents, &block)
	end

	def renderTranslationForTranslators(data)
		if !data.has_key?(:value) || data[:value].blank?
			if data.has_key?(:optional) && data[:optional]
				return ('<span class="default-value">' + (_'translate.pages.default_value') + '</span>').html_safe
			end
			return ('<span class="undefined">' + (_'translate.pages.no_value') + '</span>').html_safe
		end
		value = data[:value]
		if data.has_key?('vars') && data['vars'].present?
			data['vars'].each { |var|
				varName = var
				className = 'variable'
				if var == 'count'
					varName = '##'
					className += ' special'
				end
				value = value.gsub("%{#{var}}", "<span class=\"#{className}\">#{varName}</span>")
			}
		end
		value.html_safe
	end

	def page_needs_translations?
		I18n.backend.page_needs_translations?
	end

	def translations_needed_banner!(args = {})
		args[:volunteer_link] ||= nil
		args[:attract_volunteers] ||= false
		render 'translations/translations_needed_banner', args
	end

	def language_name(code)
		_"languages.#{code.to_s}"
	end

end

ActionView::Base.send :include, LinguaFrancaHelper
