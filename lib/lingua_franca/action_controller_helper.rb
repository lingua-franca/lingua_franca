require "action_controller"
require "http_accept_language"

ActionController::Base.class_eval do
  before_filter :lingua_franca_capture_request_info
  after_filter :lingua_franca_fix_html

  def lingua_franca_capture_request_info
    if I18n.backend.is_a?(I18n::Backend::LinguaFranca)
      LinguaFranca.set_request(request)
      LinguaFranca.set_application(Rails.application)
      
      # set the translator to the current user if we're logged in
      I18n.config.translator = current_user if self.respond_to?(:current_user)
      I18n.config.callback = self

      locale_status = (LinguaFranca.set_locale request.host, params)
      if locale_status.nil?
        locale_not_detected!
      elsif !locale_status
        case I18n.config.language_detection_method
        when I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM
          locale = params[I18n.config.language_url_param.to_sym]
        when I18n::Config::DETECT_LANGUAGE_FROM_SUBDOMAIN
          locale = I18n.backend.get_locale(request.host)
        end
        
        if I18n.locale_available?(locale)
          locale_not_enabled!(locale)
        else
          locale_not_available!(locale)
        end
      elsif I18n.config.language_detection_method == I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM
        session[:current_locale] = I18n.locale
      end

      LinguaFranca.debugging = request.params['i18nDebug']
    end
  end

  def lingua_franca_fix_html
    if LinguaFranca.debugging? && response.content_type == 'text/html'
      # response.body = response.body.
      #   # replace inner keys
      #   gsub(/#{LinguaFranca::REGEX_START_TRANSLATION}([^#{LinguaFranca::REGEX_END_TRANSLATION}]*)#{LinguaFranca::REGEX_START_TRANSLATION}(.*?)#{LinguaFranca::REGEX_END_TRANSLATION}/, "#{LinguaFranca::START_TRANSLATION}\\1\u000E\\2\u000F").
      #   # replace keys in html attributes
      #   gsub(
      #     /(<[^<]*\s)([\w\-_]+)="(#{LinguaFranca::REGEX_START_TRANSLATION}[^#{LinguaFranca::REGEX_END_TRANSLATION}]*)<!\-\-([^\"]*)\-\->#{LinguaFranca::REGEX_END_TRANSLATION}"/,
      #     "\\1\\2=\"\\3#{LinguaFranca::END_TRANSLATION}\" lingua-franca-attr-key=\"\\2:\\4\"").
      #   # replace keys in text nodes
      #   gsub(
      #     # 1=>        2=value    3=key      4=</
      #     /(>\s*#{LinguaFranca::REGEX_START_TRANSLATION})([^#{LinguaFranca::REGEX_END_TRANSLATION}]*)<!\-\-(.*?)\-\->(#{LinguaFranca::REGEX_END_TRANSLATION}\s*<\/)/,
      #     ' lingua-franca-key="\3"\1\2\4').
      #   gsub(
      #     /(<[^<]*\s)([\w\-_]+)="(#{LinguaFranca::REGEX_START_TRANSLATION}.*?)\u000E([^\u000F]*)<!\-\-([^\"]*)\-\->\u000F(.*?)#{LinguaFranca::REGEX_END_TRANSLATION}"/,
      #     "\\1\\2=\"\\3\\4#{LinguaFranca::END_TRANSLATION}\" lingua-franca-attr-key=\"\\2:\\5\"").
      #   gsub(
      #     # 1=>        2=value    3=key      4=</
      #     /\u000E([^\u000E\u000F]*)<!\-\-(.*?)\-\->\u000F/,
      #     '<span lingua-franca-key="\2">\1</span>')
    end

    if LinguaFranca.recording? && response.content_type == 'text/html'
      response.body = response.body.gsub('</body>', "<script id=\"lingua-franca-capture\">(function(){
          var lastCapture = '';
          function capture() {
            var httpRequest = new XMLHttpRequest();
            httpRequest.open('GET', '#{view_context.lingua_franca_capture_path}?a=#{params[:action]}&c=#{params[:controller]}');
            httpRequest.send();
            lastCapture = document.body.innerHTML;
          }
          capture();
          setInterval(function() {
            if (document.body.innerHTML !== lastCapture) {
              capture();
            }
          }, 200);
        })()</script></body>")
    end
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

module LinguaFrancaActionMailer
  def mail(*args)
    LinguaFranca.last_email_name = caller_locations(1, 1).first.label if LinguaFranca.recording?
    super(*args)
  end
end

module ActionMailer
  class Base
    prepend LinguaFrancaActionMailer
  end
end
