require 'i18n'
require 'set'
require 'cgi'

require 'lingua_franca/i18n/backend'
require 'lingua_franca/action_view_helper'
require 'lingua_franca/action_controller_helper'
require 'lingua_franca/activerecord'
require 'lingua_franca/action_mailer'

module LinguaFranca
  module TestModes
    RECORD = 'RECORD'
  end

  START_TRANSLATION = '<!-- lingua_franca_start(${key}) -->'
  END_TRANSLATION = '<!-- lingua_franca_end(${key}) -->'
  KEY_MATCH = '${key}'
  KEY_MATCH_REGEX = Regexp.escape('${key}')
  REGEX_START_TRANSLATION = Regexp.escape(START_TRANSLATION).gsub(KEY_MATCH_REGEX, '(.*?)')
  REGEX_END_TRANSLATION = Regexp.escape(END_TRANSLATION).gsub(KEY_MATCH_REGEX, '(.*?)')
  SANITIZE_HTML_REGEX = {
    '<\1(\2)\3>' => /&lt;(!\-\- lingua_franca_(?:start|end))\((.*?)\)( \-\-)&gt;/,
    '' => /(0x[a-z0-9]+&gt;|<\/:[^>]+:0x[a-z0-9]+>)/ # gets injected by ActionMailer
  }

  class << self

    def test(mode, &block)
      ENV['_lingua_franca_test'] = mode
      last_request = nil

      case mode
      when TestModes::RECORD
        # clear the translation info before recording
        write_translation_info

        # get rid of te recording directory if it exists
        FileUtils.rm_rf(recording_dir)
        # get rid of the failed test dir if it exists
        FileUtils.rm_rf(failed_test_dir)
        # re-make the recording dir
        FileUtils.mkdir_p(recording_dir)
      end

      # run the tests
      passed = true
      begin
        yield
      rescue
        passed = false
      end

      case mode
      when TestModes::RECORD
        if passed
          # replace the current records
          FileUtils.rm_rf(last_test_dir)
          if Dir.exists?(records_dir)
            FileUtils.mv(records_dir, last_test_dir)
          end

          FileUtils.rm(info_file)
          FileUtils.mv(recording_info_file, info_file)
          
          version_file = File.join(recording_dir, '.version')
          File.open(version_file, 'w') { |f| f.write((Time.new.to_i - 1492600000).to_s(36)) }

          FileUtils.mv(recording_dir, records_dir)
        else
          # don't replace the records if the tests failed
          FileUtils.mv(recording_dir, failed_test_dir)
        end
      end

      ENV['_lingua_franca_test'] = nil
    end

    def info_file
      I18n.config.info_file
    end

    def recording_info_file
      I18n.config.info_file.gsub(/^(.*\/)(.*?)$/, '\1.\2')
    end

    def records_dir
      I18n.config.html_records_dir
    end

    def recording_dir
      "#{I18n.config.html_records_dir}-testing"
    end

    def last_test_dir
      "#{I18n.config.html_records_dir}-last-test"
    end

    def failed_test_dir
      "#{I18n.config.html_records_dir}-failed"
    end

    def test_mode
      return ENV['_lingua_franca_test']
    end

    def recording?
      test_mode == TestModes::RECORD
    end

    def debugging=(state)
      @_lingua_franca_debug = state
    end

    def debugging?
      @_lingua_franca_debug
    end

    def debugging
      @_lingua_franca_debug
    end

    def set_application(application)
      @application = application
    end

    def set_request(request)
      @request = request
    end

    def check_request
      if new_request?
        last_request = @request.uuid
      end
    end

    def host
      @@host
    end

    def host=(host)
      @@host = host
    end

    def test_driver
      @@test_driver
    end

    def test_driver=(driver)
      @@test_driver = driver
    end

    def last_email_name
      @@last_email_name
    end

    def last_email_name=(method_name)
      @@last_email_name = method_name
    end

    def test_version(app_slug, app_path)
      version_file = File.expand_path(File.join(app_path, records_dir, '.version'))
      File.exist?(version_file) ? File.read(version_file).strip : nil
    end

    def get_html(distance_from_root = 4)
      public_dir = "#{'../' * distance_from_root}public/"
      test_driver.html.gsub(/(=\"|\(['"]?)(?:#{host})?\/(assets|uploads)/, "\\1#{public_dir}\\2")
        .gsub(/<script id="lingua\-franca\-capture">.*?<\/script>\s*/m, '')
        .gsub(/<script type="json" id="lingua\-franca\-translations">.*?<\/script>\s*/m) { |m| m.gsub(/\\u003c!\-\-/, '<!--').gsub(/\-\-\\u003e/, '-->') }
    end

    def screenshot_mail
      emails = Dir.glob(File.join(recording_dir, 'email', '*.html')) +
        Dir.glob(File.join(recording_dir, 'email', '*.txt'))

      emails.each do |file|
        # assemble the png file name
        png_file = File.expand_path(file + '.png')
  
        unless File.exist? png_file
          # if it doesn't exist already, load it and take a screenshot
          test_driver.visit('file:///' + File.expand_path(file).gsub(/\\/, '/'))

          # set the background to white 
          test_driver.evaluate_script("document.body.bgColor = '#FFF';");
          
          # resize the window to capture the mobile version
          old_size = test_driver.browser.client.window_size
          test_driver.resize_window(600, 400)

          test_driver.save_screenshot(png_file, full: true)

          test_driver.resize_window(*old_size)
        end
      end
    end

    def capture_translations
      data = {}
      Dir.glob(File.join(recording_dir, '*', '*.html')).each do |file|
        sanitized_html, keys = analyze_html(html)
        group = File.basename(File.dirname(file))
        page, page_index = File.basename(file).split('--')
        page_index = page_index.gsub(/^(\d+).*$/, '\1').to_i
        data = collect_translations(data, keys, current_page(page, group), page_index)
      end
      write_translation_info(data)
    end

    def capture_mail(mail)
      FileUtils.mkdir_p(recording_dir)
      FileUtils.mkdir_p(File.join(recording_dir, 'email'))

      begin
        mail.body.parts.each do |part|
          type = part.header.first.field.element.sub_type
          unless type == 'plain' # hold back on recording plain text until we can fix it
            extension = type == 'plain' ? 'plain.txt' : 'html'

            capture_html(part.body.raw_source, last_email_name, 'email', {
                extension: extension, ensure_translated: type != 'plain'
              })
          end
        end
      rescue Exception => exception
        puts exception.to_s
        puts exception.backtrace.join("\n")
      end
    end

    def capture_request(action = nil, controller = nil)
      if test_driver.respond_to?(:html)
      
        filename = capture_html(get_html, action, controller)

        if test_driver.respond_to?(:save_screenshot) && filename.present?
          png_filename = filename.gsub(/.html$/, '.png')
          png_mobile_filename = filename.gsub(/.html$/, '.mobile.png')

          # save the desktop version
          # sleep 0.25 # sleep to make sure the browser has time to adjust
          test_driver.save_screenshot(File.expand_path(png_filename), full: true)

          # resize the window to capture the mobile version
          old_size = test_driver.browser.client.window_size
          test_driver.resize_window(375, 667)
          # sleep 0.25 # sleep to make sure the browser has time to adjust
          test_driver.save_screenshot(File.expand_path(png_mobile_filename), full: true)
          test_driver.resize_window(*old_size)
        end
      end
    end

    def analyze_html(html, keys = nil)
      keys ||= {}

      head, comment, key, tail = html.split(/(#{REGEX_START_TRANSLATION})/, 2)

      return [html, keys] if key.nil?

      if key.present?
        key, key_data = key.split(',', 2)
        keys[key] ||= []
        keys[key] << CGI::unescapeHTML(key_data || '{}')
      end

      translation, tail = tail.split(/#{REGEX_END_TRANSLATION.gsub('(.*?)', key)}/, 2)

      translation_keys = nil
      while translation_keys.nil? || translation_keys.present?
        translation, translation_keys = analyze_html(translation)
        keys.merge!(translation_keys)
      end

      return analyze_html(head + (tail || ''), keys)
    end

    def capture_html(html, action = nil, controller = nil, options = {})
      page_name = current_page(action, controller)
      return nil unless page_name.present?

      # remove translated content from the HTML
      SANITIZE_HTML_REGEX.each { |replace, regex| html.gsub!(regex, replace) }

      data = get_translation_info

      sanitized_html, keys = analyze_html(html)

      # strip out all the HTML, some weird string show up from time to time (particularly in emails)
      stripped_string = ActionView::Base.full_sanitizer.sanitize(sanitized_html.gsub(/<title[\s>].*?<\/title>/m, '')).gsub(/(\b)\d(\b)/, '\1\2')

      # if anything is left other than whitespace, there must be content that is not translated
      unless options[:ensure_translated] == false || stripped_string.gsub(/\s*/, '').blank?
        # so fail any tests that might be happening
        fail "Untranslated content found: [#{stripped_string.strip.gsub(/\s+/, ' ')}] in:\n\t#{sanitized_html.gsub(/\s+/m, ' ')}"
      end

      html_file = nil

      extension = options[:extension] || 'html'

      @@html_cache ||= {}
      @@html_cache[page_name] ||= {}
      @@html_cache[page_name][extension] ||= []

      page_index = nil

      i = 0
      while page_index.nil? && i < @@html_cache[page_name][extension].size
        # compare the HTML without translations so that we don't repeat a page just because it has
        #   a different value
        if @@html_cache[page_name][extension][i] == sanitized_html
          page_index = i
        end
        i += 1
      end

      if page_index.nil?
        page_index = @@html_cache[page_name][extension].size
        @@html_cache[page_name][extension] << sanitized_html
        FileUtils.mkdir_p(recording_dir)
        FileUtils.mkdir_p(File.join(recording_dir, controller || @request[:controller]))
        html_file = File.join(recording_dir, "#{page_name}--#{page_index}.#{extension}")
        File.open(html_file, 'w') { |f| f.write(html) }
      end

      # record which translations were found on this variation
      data = collect_translations(data, keys, page_name, page_index)
      write_translation_info(data)

      return html_file
    end

    def collect_translations(data, keys, page_name, page_index)
      keys.each do |key, key_data|
        data[key] ||= {}
        data[key][page_name] ||= {}
        data[key][page_name]['indices'] ||= []        
        data[key][page_name]['indices'] << page_index unless data[key][page_name]['indices'].include?(page_index)

        if data.present?
          key_data.each do |kd|
            keydata = begin
                        JSON.parse(kd)
                      rescue JSON::ParserError
                        JSON.parse(CGI::unescapeHTML(kd))
                      end
            keydata.each do |k,v|
              data[key][page_name]['data'] ||= {}
              if k == 'vars'
                data[key][page_name]['data']['vars'] ||= {}
                v.each do |var_key, var_value|
                  data[key][page_name]['data']['vars'][var_key] ||= []
                  data[key][page_name]['data']['vars'][var_key] |= [var_value]
                end
              else
                data[key][page_name]['data'][k] = v
              end
            end
          end
        end
      end
      return data
    end

    def example_file_path(app_path, group, page, index, extension = 'html')
      File.expand_path(File.join(app_path, records_dir, group, "#{page}--#{index}.#{extension}"))
    end

    def load_example(app_path, group, page, index)
      File.read(example_file_path(app_path, group, page, index))
    end

    def last_request=(request)
      ENV['_lingua_franca_last_request'] = request
    end

    def last_request
      return ENV['_lingua_franca_last_request']
    end

    def new_request?
      last_request != (@request.present? ? @request.uuid : nil)
    end

    def request_id
      @request.present? ? @request.uuid : nil
    end

    def current_page(action, controller)
      File.join(controller, action)
    end

    def get_route(path)
      @application.routes.routes.each do |route|
        if route.defaults[:controller] == @request[:controller] && route.defaults[:action] == @request[:action]
          return {
            name: route.name,
            path: route.path.spec.to_s
          }
        end
      end
      return "#{@request[:controller]}__#{@request[:action]}"
    end

    def record_translation(locale, key, options, translation)
      translation
    end

    def reserved?(word)
      word.to_s =~ I18n::RESERVED_KEYS_PATTERN
    end

    def with_locale(locale, &block)
      old_locale = I18n.locale
      I18n.locale = locale
      yield
    ensure
      I18n.locale = old_locale
    end

    # Sets the current locale based on the URL and user settings
    # If the language is detected and it is avilable, the current locale is set the locale detected
    # If the language language is not detected or is not available, the current locale
    #  is set to the user's settings using the Accept-Language header, or the default locale
    #
    # Returns:
    # =>  true if the language is detected and it is enabled, the page should be shown
    # =>  false if the language is detected and it is not enabled, a 404 page should be shown
    # =>  nil if the language was detectable from the given host, a redirect should probably occur
    def set_locale(host, params, default_locale = I18n.default_locale)
      case I18n.config.language_detection_method
        when I18n::Config::DETECT_LANGUAGE_FROM_URL_PARAM
          lang = params[I18n.config.language_url_param.to_sym]
        when I18n::Config::DETECT_LANGUAGE_FROM_SUBDOMAIN
          @@hosts ||= Hash.new
          if @@hosts.has_key?(host)
            return @@hosts[host]
          end
          lang = get_locale(host)
      end
      if lang.present? && locale_enabled?(lang)
        I18n.locale = lang
        return true
      end
      I18n.locale = I18n.default_locale
      return (lang.present? && I18n.locale_available?(lang)) ? false : nil
    end

    # Determines the locale based on the current URL
    def get_locale(host)
      host.gsub(I18n.config.host_locale_regex, '\1') || I18n.default_locale
    end

    # Returns a hash containing a list of all keys and data on how they are used
    def get_translation_info(app = nil)
      @@translation_info ||= {}

      unless @@translation_info[app].present?
        if app.present?
          location = File.join(app, info_file)
        else
          location = info_file
        end

        if File.exists?(location)
          @@translation_info[app] = YAML.load_file(location) || {}
        end
      end

      return @@translation_info[app] || {}
    end

    def write_translation_info(translations = {})
      File.open(recording_info_file, 'w') { |f| f.write translations.to_yaml }
    end

    def backend_for_app(app_slug, app_path)
      @@backends ||= {}
      
      @@backends[app_slug.to_sym] ||= I18n::Backend::LinguaFranca.new

      i18n = @@backends[app_slug.to_sym]
      
      unless i18n.loaded?
        # load all translations for all enabled locales
        enabled_locales(app_slug, app_path).each do |locale|
          i18n.load(locale_file(app_path, locale))
        end
      end

      return i18n
    end
    
    def reload_backend(app_slug, app_path)
      @@translations[app_slug] = nil
      backend_for_app(app_slug, app_path).clear_store
      backend_for_app(app_slug, app_path)
    end

    def save_translation(app_slug, app_path, locale, key, value, options = {})
      save_translations(app_slug, app_path, locale, { key => value }, options = {})
    end

    def save_translations(app_slug, app_path, locale, data, options = {})
      i18n = backend_for_app(app_slug, app_path)

      new_data = {}
      data.each do | key, value |
        new_data.deep_merge!(expand_key(key, value))
      end

      i18n.store_translations(locale, new_data, options)
      i18n.save_translations(locale, locale_file(app_path, locale))

      reload_backend(app_slug, app_path)
    end

    def get_translations(app_slug, app_path, locale)
      @@translations ||= {}
      @@translations[app_slug] ||= {}
      unless @@translations[app_slug][locale].present?
        @@translations[app_slug][locale] = backend_for_app(app_slug, app_path).get_translations(locale).stringify_keys
      end
      return @@translations[app_slug][locale] || {}
    end

    def locales_path(app_path = nil)
      File.expand_path(File.join(*[app_path, 'config', 'locales'].compact))
    end

    def locale_file(app_path, locale, enabled = true)
      File.join(locales_path(app_path), "#{enabled ? '' : '.'}#{locale.to_s}.yml")
    end

    def locale_stats(app_slug, app_path, locale)
      translations = LinguaFranca.get_translations(app_slug, app_path, locale)
      return nil if translations.nil?

      info = get_translation_info(app_path)

      complete = 0
      total = 0
      info.each do |key, page_info|
        if page_info.values.first['data'].present? && page_info.values.first['data']['vars'].present? && page_info.values.first['data']['vars']['count'].present?
          [:one, :other].each do |v|
            total += 1
            complete += 1 if translations[key].present? && translations[key][v].present?
          end
        else
          unless imported_translation?(key)
            total += 1
            complete += 1 if translations[key].present?
          end
        end
      end

      { total: total, complete: complete }
    end

    def imported_translation?(key)
      key =~ /(?:^geography\.(?:countries|subregions)\.|^languages\.|^currencies\.|\[[0-9]+\]$)/
    end

    def locale_enabled?(locale, app_slug = nil, app_path = nil)
      enabled_locales(app_slug, app_path).include?(locale.to_sym)
    end

    def enabled_locales(app_slug = nil, app_path = nil)
      @@enabled_locales ||= {}
      @@enabled_locales[app_slug] ||= nil

      if @@enabled_locales[app_slug].nil?
        @@enabled_locales[app_slug] = available_locales.select do |locale|
          File.exists?(locale_file(app_path, locale))
        end
      end

      return @@enabled_locales[app_slug]
    end

    def available_locales
      @@available_locales ||= nil

      if @@available_locales.nil?
        @@available_locales = []
        Dir.glob(File.join(Gem.loaded_specs['rails-i18n'].full_gem_path, 'rails', 'locale', '*.yml')).each do |file|
          locale = File.basename(file, '.yml')
          @@available_locales << locale.to_sym if locale =~ /^[a-z]{2,3}$/
        end
      end

      return @@available_locales
    end

    def get_context(context)
      case context.to_s
        when 'c', 'char', 'chars', 'character', 'characters'
          return 'character'
        when 'w', 'word', 'words'
          return 'word'
        when 's', 'sentence', 'sentences'
          return 'sentence'
        when 't', 'title'
          return 'title'
        when 'p', 'paragraph', 'paragraphs'
          return 'paragraph'
      end
      return nil
    end

  private

    def expand_key(key, value)
      expanded = value
      key.split('.').reverse.each do |part|
        expanded = { part => expanded }
      end
      return expanded
    end
  end
end

require 'lingua_franca/railtie' if defined?(Rails::Railtie)
