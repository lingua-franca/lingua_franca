require "action_view"

module LinguaFrancaHelper
	def _(*args, &block)#key, context = nil, context_size = nil, locale: nil, vars: {})#, html: nil, blockData: {}, &block)
		wrapper = I18n.backend.html_wrapper(*args)
		if block_given?
			I18n.backend.push(*args)
			return (wrapper.first + capture(&block) + wrapper.last).html_safe
		end
		(wrapper.first + I18n.backend._(*args) + wrapper.last).html_safe
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

	def _!
		I18n.backend.pop
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
