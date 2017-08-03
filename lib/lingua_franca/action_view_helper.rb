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

      return inner_html.html_safe
    end
    # I18n.backend.wrap(inner_html || I18n.backend._(*args), *args, &block).html_safe
    I18n.backend._(*args)
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

  def language_name(locale, original_language = false)
    args = {}
    args[:locale] = locale if original_language
    _("languages.#{locale}", args)
  end

  def url_params(locale, params = {})
    case I18n.config.language_detection_method
      when I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM
        params[:params] ||= {}
        params[:params][I18n.config.language_url_param] = locale.to_s
      when I18n::Config::DETECT_LANGUAGE_FROM_SUBDOMAIN
        params[:subdomain] = I18n.config.subdomain_format.gsub('%', locale.to_s)
    end
    return params
  end

  def add_js_translation(key, locale = I18n.locale)
    @_js_translations ||= Hash.new
    @_js_translations[locale] ||= Hash.new
    value = I18n.translate(key, locale: locale, resolve: false)
    key.to_s.split('.').reverse_each do |sub_key|
      value = { sub_key => value }
    end
    @_js_translations[locale].merge! value
  end

  def emit_js_translations()
    @_js_translations ||= nil
    return unless @_js_translations.present?

    js = File.read(File.join(Rails.public_path, ActionController::Base.helpers.asset_path("lingua-franca.js")))

    return (content_tag(:script, @_js_translations.to_json.to_s.html_safe, type: :json, id: 'lingua-franca-translations') + 
      content_tag(:script, js.html_safe)).html_safe
  end
end

ActionView::Base.send :include, LinguaFrancaHelper
