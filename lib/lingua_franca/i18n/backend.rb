require 'i18n'
require 'yaml'
require 'cgi'
require 'lingua_franca/i18n/config'
require 'lingua_franca/i18n/exception_handler'

module I18n

  module Backend
    LOCALE_NOT_PRESENT    = 1
    LOCALE_NOT_ENABLED    = 2
    LOCALE_NOT_RECOGNIZED = 3

    class LinguaFranca < I18n::Backend::Simple

      include I18n::Backend::Cache
      include I18n::Backend::Flatten
      include I18n::Backend::Pluralization

      def translations_blocked
        @@block_translations ||= false
      end

      def set_test_name(name)
        @@test_name = name
      end

      def set_page_name(name)
        @@page_override ||= false
        if @@page_override === true
          return @@page_name
        end
        @@page_name ||= nil
        old_name = @@page_name
        @@page_names ||= []
        
        if name.nil?
          @@page_name = nil
          return old_name
        end

        @@test_name ||= nil
        if @@test_name
          @@page_name = "#{@@test_name}--#{name}"
          while @@page_names.include? @@page_name
            id ||= 0
            id += 1
            @@page_name = "#{@@test_name}--#{name}-#{id}"
          end
          @@page_names << @@page_name
        end
        return old_name
      end

      # Initializes the page, takes in request and params for recording
      #  contextual information about translations during testing
      def init_page(request, params)
        init_request
      end

      def init_request
        if ENV["RAILS_ENV"] == 'test'
          @@request_id ||= 0
          @@request_id += 1
        end
      end

      def needs_translation(key)
        @@needs_translation ||= Array.new
        if !@@needs_translation.include?(key)
          @@needs_translation << key
        end
      end

      # Initialize the I18n backend
      def initialize

        I18n.exception_handler = I18n::LinguaFrancaMissingTranslation.new
        unless File.exist?(I18n.config.info_file)
          dir = File.dirname(I18n.config.info_file)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)
          File.open(I18n.config.info_file, 'w+')
        end

        # throw an exception if we're missing the pluralizations rules file
        throw Exception("Lingua Franca: Missing Pluralization File #{I18n.config.languages_file}") unless File.exist?(I18n.config.languages_file)
        
        super
      end

      # Reload translations
      def reload!
        reset_stats!
        super
      end

      def reset_stats!
        @@available_locales = nil
        @@enabled_locales = nil
        @@language_completion = nil
        @@all_translation_info = nil
        @@datetime_vars = nil
      end

      def load_translations(*filenames)
        # load defaults unless we we're provided a list of files to load
        unless filenames.present?
          filenames = Dir.glob(File.join(Gem.loaded_specs['rails-i18n'].full_gem_path, 'rails', 'locale', "*.yml")) +
            [ I18n.config.languages_file, I18n.config.geography_file ] + I18n.load_path
        end
        
        super(filenames || [])
      end

      def clear_store
        @loaded = false
        @store = {}
      end

      def loaded?
        @loaded ||= false
      end

      def load(file)
        @loaded = true

        [file, I18n.config.languages_file, I18n.config.geography_file].each do |f|
          if File.exists?(f)
            YAML.load_file(f).each do |locale, data|
              store_translations(locale, data || {})
            end
          end
        end
      end

      def get_translations(locale)
        flatten_translations(locale.to_sym, translations[locale.to_sym], true, true)
      end

      def pluralization_rules(locale = nil)
        return [:zero, :one, :two, :few, :many, :other] unless locale.present?

        @@pluralization_rules ||= Hash.new
        # load the rules if a locale was provided
        locale = locale.to_sym

        return @@pluralization_rules[locale] if @@pluralization_rules.has_key?(locale)

        pluralization_file = File.join(Gem.loaded_specs['rails-i18n'].full_gem_path, "rails/pluralization/#{locale.to_s}.rb")

        unless File.exist?(pluralization_file)
          # if we didn't file pluralization rules, the language must use the default just like English
          return (@@pluralization_rules[locale] = pluralization_rules(:en))
        end

        @@pluralization_rules[locale] ||= load_rb(pluralization_file)[locale.to_sym][:i18n][:plural][:keys]
      end

      # Determines the locale based on the current URL
      def get_locale(host)
        host.gsub(I18n.config.host_locale_regex, '\1') || I18n.default_locale
      end

      # Returns a list of all locales that the site currently supports or could support in the future
      def available_locales
        ::LinguaFranca.available_locales
      end

      # Returns a list of locales that are ready for production
      # Each locale must meet a minimum completion percentage which can be set by config.language_threshold
      # The threshold is measured by the total number of keys avilable for translation divided by the total
      #  number of keys that have translations for each locale
      def enabled_locales(app_path = nil)
        ::LinguaFranca.enabled_locales(app_path)
      end

      # Measures the language completion for a given locale
      # Return a number from 0 to 100 which is determined by dividing the total number of 
      #  translatable keys by the total number of keys with translations for this locale
      def get_language_completion(locale)
        @@language_completion ||= {}
        locale = locale.to_s

        if @@language_completion.has_key?(locale)
          return @@language_completion[locale]
        end

        # return nil if we haven't got all of our base translations in
        return nil unless File.exists?("config/locales/#{locale}.yml")

        # return the percentage of translations in use
        @@language_completion[locale] = _get_language_completion(locale, translation_info(locale))

      end

      # Determines if a locale is production ready and can be seen by any visitor
      # The default locale is always available, all other locales are measured for completion
      #  and compared against config.language_threshold to make sure the amount of translations
      #  available meet the minimum requirements
      def locale_enabled?(locale)
        locale.to_s == I18n.default_locale.to_s || (get_language_completion(locale) || -1) >= I18n.config.language_threshold
      end

      def validate_translation(locale, key, value)
        nil
      end

      def languages
        YAML.load_file(I18n.config.languages_file)['en']['languages'].keys
      end

      def language_info(locale = I18n.locale, lookup = true)
        info = {}
        languages.each { |language|
          info["languages.#{language}"] = {
            :value => lookup ? lookup_raw(locale, "languages.#{language}") : nil,
            :pages => nil,
            :data => nil,
            :context => :language
          }
        }
        info
      end

      def geography
        places = {}
        data = YAML.load_file(I18n.config.geography_file)['en']['geography']
        data['countries'].keys.each { |country|
          places[country] = Array.new
          (data['subregions'][country] || {}).keys.each { |subregion|
            places[country] << subregion
          }
        }
        places
      end

      def geography_info(locale = I18n.locale, lookup = true)
        info = {}
        geography.each { |country, subregions|
          info["geography.countries.#{country}"] = {
            :value => lookup ? lookup_raw(locale, "geography.countries.#{country}") : nil,
            :pages => nil,
            :data => nil,
            :context => :geography
          }
          subregions.each { |subregion|
            info["geography.subregions.#{country}.#{subregion}"] = {
              :value => lookup ? lookup_raw(locale, "geography.subregions.#{country}.#{subregion}") : nil,
              :pages => nil,
              :data => nil,
              :context => :geography
            }
          }
        }
        info
      end

      def translation_info(locale = I18n.locale, lookup = true)
        info = {}
        plurals = pluralization_rules(locale)
        ::LinguaFranca.get_translation_info().each do |key, data|
          info[key] = data
          value = info[key][:value] = nil
          if lookup
            catch(:exception) do
              value = info[key][:value] = lookup_raw(locale, key)
            end
          end
          if data.has_key?('vars') && data['vars'].include?(:count)
            info[key][:count] = true
            info[key][:value] = Hash.new
            (plurals | [:zero]).each { |rule|
              info[key][:value][rule] = value.blank? ? nil : value[rule.to_sym]
            }
            info[key][:zero_optional] = !plurals.include?(:zero)
          else
            info[key][:value] = value
          end
          info[key]['pages'] = (data['pages'] || []).collect { |page| ::LinguaFranca.get_route(page) }
        end
      end

      def lingua_franca_translation_info(locale = I18n.locale, lookup = true)
        info = YAML.load_file(File.join(File.expand_path('../../../..', __FILE__), 'config/locales/data/lingua_franca-translation-info.yml'))
        plurals = pluralization_rules(locale)
        info.each { |key, data|
          if lookup
            value = lookup_raw(locale, key)

            if data.has_key?('vars') && data['vars'].include?('count')
              info[key][:count] = true
              info[key][:value] = Hash.new
              (plurals | [:zero]).each { |rule|
                info[key][:value][rule] = value.blank? ? nil : value[rule.to_sym]
              }
              info[key][:zero_optional] = !plurals.include?(:zero)
            else
              info[key][:value] = value
            end
          end
        }
        info
      end

      def datetime_vars
        @@datetime_vars ||= {
          y: I18n.t('translate.datetime.year_two_digit', :context => 'year (00-99)'),
          Y: I18n.t('translate.datetime.year_four_digit', :context => 'year ####'),
          b: I18n.t('translate.datetime.month_abbr', :context => 'month abbr'),
          B: I18n.t('translate.datetime.month_name', :context => 'month name'),
          m: I18n.t('translate.datetime.month_two_digit', :context => 'month (01-12)'),
          a: I18n.t('translate.datetime.weekday_abbr', :context => 'weekday abbr'),
          A: I18n.t('translate.datetime.weekday_name', :context => 'weekday'),
          e: I18n.t('translate.datetime.day', :context => 'day (1-31)'),
          d: I18n.t('translate.datetime.day_padded', :context => 'day (01-31)'),
          p: I18n.t('translate.datetime.AMPM', :context => 'AM/PM'),
          P: I18n.t('translate.datetime.ampm', :context => 'am/pm'),
          l: I18n.t('translate.datetime.hour_12', :context => 'hour (1-12)'),
          k: I18n.t('translate.datetime.hour_24', :context => 'hour (0-23)'),
          I: I18n.t('translate.datetime.hour_12_padded', :context => 'hour (01-12)'),
          H: I18n.t('translate.datetime.hour_24_padded', :context => 'hour (00-23)'),
          M: I18n.t('translate.datetime.minute', :context => 'minute (00-59)'),
          S: I18n.t('translate.datetime.second', :context => 'second'),
          z: I18n.t('translate.datetime.timezone_offset', :context => 'timezone offset'),
          Z: I18n.t('translate.datetime.timezone_abbr', :context => 'timezone abbr')
        }
      end

      def all_translation_info(locale = I18n.locale, lookup = true)
        @@all_translation_info ||= {:lookup => Hash.new, :dont_lookup => Hash.new}
        lookup_key = lookup ? :lookup : :dont_lookup
        
        return @@all_translation_info[lookup_key][locale] if @@all_translation_info[lookup_key].has_key?(locale)

        info =
          lingua_franca_translation_info(locale, lookup).
          merge(geography_info(locale, lookup)).
          merge(language_info(locale, lookup)).
          merge(translation_info(locale, lookup))

        if lookup
          info.each { |key, data|
            if key =~ /(^|\.)(date|time)\.formats\.[^\.]+$/
              info[key][:datetime] = true
              info[key][:vars] = datetime_vars
            end
          }
        end

        @@all_translation_info[lookup_key][locale] ||= info
      end

      def _(key, context = nil, context_size = nil, vars: {}, locale: nil, &block)
        options = vars
        if context
          options[:context] = context
          options[:context_size] = context_size
        end
        options[:locale] = locale if locale.present?
        I18n.translate(key, options)
      end

      def _!(contents, &block)
        return '' if translations_blocked
        translation = contents || capture(&block)
        if should_wrap?(translation, {})
          ::Rails.logger.info "Excluding [#{translation}]"
          translation = wrap(nil, translation)
        end
        return translation
      end

      def translate(locale, key, options = {})
        translation = super(locale, key, options)
        if should_wrap?(translation, options)
          keyname = key_name(key, options[:scope])
          ::Rails.logger.info "Looking up: [#{keyname}] = [#{translation}]"
          translation = wrap(keyname, translation, options)
        end

        return translation
      end

      def set_html(html)
        @@lingua_franca_html = html
      end

      def override_page_name(name)
        old_name = set_page_name(name)
        @@page_override = true
        return old_name
      end

      def end_page_name_override(name)
        @@page_override = false
        old_name = set_page_name(name)
        return old_name
      end

      def save_translations(locale, file)
        File.open(file, 'w+') do |f|
          f.write(({
              locale => translations[locale.to_sym].deep_stringify_keys
            }).to_yaml)
        end
      end

      protected
        def _get_language_completion(locale, _translation_info)
          total = 0
          complete = 0

          _translation_info.each { |key, info|
            if info[:count] || info['count']
              pluralization_rules(locale).each { |rule|
                total += 1
                complete += 1 unless info[:value].nil? || !info[:value].has_key?(rule) || info[:value][rule].nil?
              }
            elsif info[:value].is_a?(Hash)
              info[:value].keys.each { |rule|
                total += 1
                complete += 1 unless info[:value].nil? || !info[:value].has_key?(rule) || info[:value][rule].nil?
              }
            else
              total += 1
              complete += 1 unless info[:value].nil?
            end
          }
          (total > 0 ? complete / total.to_f : 0.0) * 100.0
        end

        def key_name(key, scope)
          key = key.to_s
          if scope.present?
            key = (scope.is_a?(Array) ? scope.join('.') : scope.to_s) + '.' + key
          end
          key
        end

        def expand_keys(keys, value)
          if keys.size > 1
            { keys.first.to_s => expand_keys(keys[1..-1], value) }
          elsif keys.size == 1
            { keys.first.to_s => value }
          end
        end

        # removes nil leaves and their parents if empty
        def deep_clean(data)
          proc = Proc.new { |k, v|
            if v.kind_of?(Hash) && !v.empty?
              v.delete_if(&proc)
              nil
            end
            v.nil? || v.empty?
          }
          hash.delete_if(&proc)
        end

        # Looks up the translation and makes a record of it if we're currently testing
        # Returns the translation or if the translation is missing it will use
        #  options[:context] to determine what to return
        def lookup(locale, key, scope = [], options = {})
          return '' if translations_blocked

          if ::LinguaFranca.debugging? && available_locales.include?(::LinguaFranca.debugging)
            locale = ::LinguaFranca.debugging
          end

          result = super(locale, key, scope, options)

          key = key_name(key, scope)

          return result
        end

        def save_change(locale, data)
          if I18n.config.translation_model
            flatten_translations(locale, data, true, false).each do |key, value|
              I18n.config.translation_model.create(
                  locale: locale,
                  translator_id: I18n.config.translator_id,
                  key: key.to_s,
                  value: value
                )
            end
          end
        end

        # Determines whether or not to make a record
        # Returns true if we're in the test environment and the behaviour is not :strict
        def should_make_record?(options = {})
          ::LinguaFranca.recording? && options[:resolve] != false
        end

        def should_wrap?(result, options = {})
          # (::LinguaFranca.recording? || ::LinguaFranca.debugging?) && (result.nil? || result.is_a?(String))
          ::LinguaFranca.recording? || ::LinguaFranca.debugging?
        end

        def wrap(key, result, options = nil)
          if result.is_a?(String)
            if key.present?
              if options.present?
                key_data = {}
                options.each do |k, v|
                  case k.to_sym
                  when :context, :context_size
                    key_data[k.to_s] = v
                  when :locale, :scope, :resolve
                    # do nothing
                  else
                    key_data['vars'] ||= {}
                    key_data['vars'][k.to_s] = v
                  end
                end
                key_data = key_data.present? ? "#{key},#{CGI::escapeHTML(key_data.to_json)}" : key
              else
                key_data = key
              end
            else
              key = ''
              key_data = ''
            end

            return (
              ::LinguaFranca::START_TRANSLATION.gsub(::LinguaFranca::KEY_MATCH, key_data) +
              result + ::LinguaFranca::END_TRANSLATION.gsub(::LinguaFranca::KEY_MATCH, key)
            ).html_safe
          elsif result.is_a?(Hash)
            new_result = {}
            result.each do |k, v|
              new_result[k] = wrap("#{key}.#{k}", v, options)
            end
            return new_result
          elsif result.is_a?(Array)
            new_result = []
            result.each_with_index do |v, i|
              new_result << wrap("#{key}[#{i}]", v, options)
            end
            return new_result
          end

          return result
        end

        def lookup_raw(locale, key, scope = [], options = {})
          init_translations unless initialized?
          keys = I18n.normalize_keys(locale, key, scope, options[:separator] || '.')

          keys.inject(translations) do |result, _key|
            _key = _key.to_sym
            result = result[_key] if result
            result
          end
        end
    end
  end
end

