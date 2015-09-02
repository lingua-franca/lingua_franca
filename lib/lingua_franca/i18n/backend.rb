require "i18n"
require "yaml"
require "lingua_franca/i18n/config"
require "lingua_franca/i18n/exception_handler"

module I18n
	module Backend
		LOCALE_NOT_PRESENT    = 1
		LOCALE_NOT_ENABLED    = 2
		LOCALE_NOT_RECOGNIZED = 3

		class LinguaFranca < I18n::Backend::Simple

			include I18n::Backend::Cache
			include I18n::Backend::Flatten
			include I18n::Backend::Pluralization

			@@translation_cache
			@@testing_started = false
			@@hosts

			# Initializes the testing environment by removing all translation info
			# Should only be called once before all tests in a test suite
			def self.init_tests!()
				if ENV["RAILS_ENV"] == 'test' && !@@testing_started
					@@testing_started = true
					File.open(I18n.config.info_file, 'w+')
					File.open(I18n.config.cache_file, 'w+')
					FileUtils.rm_rf(Dir.glob(File.join(I18n.config.html_records_dir, '*')))
					FileUtils.mkdir_p I18n.config.html_records_dir
				end
			end

			def testing_started
				@@testing_started
			end

			def start_recording_html(test_driver)
				#if ENV["RAILS_ENV"] == 'test' && @@testing_started
				#end
				@@test_driver = test_driver
			end

			def stop_recording_html#(html)
				@@page_name ||= nil
				if ENV["RAILS_ENV"] == 'test' && @@page_name && @@lingua_franca_html
					File.open(File.join(I18n.config.html_records_dir, "#{@@page_name}.html"), 'w+') {
						|f| f.write(@@lingua_franca_html.gsub(/https?:\/\/(\w\w\.)?127.0.0.1:\d+\//, '/'))
					}
				end
			end

			def start_looking_for_untranslated_content
				@@block_translations = true
			end

			def stop_looking_for_untranslated_content
				@@block_translations = false
			end

			def translations_blocked
				@@block_translations ||= false
			end

			def set_test_name(name)
				@@test_name = name
			end

			def set_page_name(name)
				@@page_names ||= []
				
				if name.nil?
					@@page_name = nil
					return
				end

				@@page_name = "#{@@test_name}--#{name}"
				while @@page_names.include? @@page_name
					id ||= 0
					id += 1
					@@page_name = "#{@@test_name}--#{name}-#{id}"
				end
				@@page_names << @@page_name
			end

			# Initializes the page, takes in request and params for recording
			#  contextual information about translations during testing
			def init_page(request, params)
				@@page_info = {
					:path => request.env['PATH_INFO'],
					:controller => params['controller'],
					:action => params['action']
				}
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
				if !File.exist?(I18n.config.info_file)
					dir = File.dirname(I18n.config.info_file)
					FileUtils.mkdir_p(dir) unless File.directory?(dir)
					File.open(I18n.config.info_file, 'w+')
				end

				# throw an exception if we're missing the pluralizations rules file
				if !File.exist?(I18n.config.languages_file)
					throw Exception("Lingua Franca: Missing Pluralization File #{I18n.config.languages_file}")
				end

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
				if filenames.present?
					super(filenames)
				end

				filenames = Dir.glob(File.join(Gem.loaded_specs['rails-i18n'].full_gem_path, 'rails', 'locale', "*.yml"))
				filenames << I18n.config.languages_file
				filenames << I18n.config.geography_file
				filenames += I18n.load_path
				super(filenames)
			end

			# Returns a hash containing a list of all keys and data on how they are used
			def get_translation_info()
				YAML.load_file(I18n.config.info_file) || {}
			end

			def pluralization_rules(locale = nil)
				return [:zero, :one, :two, :few, :many, :other] unless locale.present?

				@@pluralization_rules ||= Hash.new
				# load the rules if a locale was provided
				locale = locale.to_sym

				return @@pluralization_rules[locale] if @@pluralization_rules.has_key?(locale)

				pluralization_file = File.join(Gem.loaded_specs['rails-i18n'].full_gem_path, "rails/pluralization/#{locale.to_s}.rb")

				if !File.exist?(pluralization_file)
					# if we didn't file pluralization rules, the language must use the default just like English
					return (@@pluralization_rules[locale] = pluralization_rules(:en))
				end

				@@pluralization_rules[locale] ||= load_rb(pluralization_file)[locale.to_sym][:i18n][:plural][:keys]
			end

			def pattern_from(args)
				array = Array(args || [])
				array.blank? ? '*' : "{#{array.join ','}}"
			end

			# Determines the locale based on the current URL
			def get_locale(host)
				#if host =~ /^((\d{1,3}\.){3}\d{1,3})|(localhost)$/
				#	# we can't get any info from this address, it's probably the dev environment
				#	return I18n.default_locale
				#end
				#host.gsub(/^(https?:\/\/)?((dev|test|www)\.)?(([^\.]+)\.)?.*\.([^\.]{2,7})$/, '\5')
				host.gsub(I18n.config.host_locale_regex, '\1') || I18n.default_locale
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
				if lang.present? && (locale_enabled?(lang) || can_translate?)
					I18n.locale = lang
					return true
				end
				I18n.locale = I18n.default_locale
				return (lang.present? && I18n.locale_available?(lang)) ? false : nil
			end

			# Returns a list of all locales that the site currently supports or could support in the future
			def available_locales
				locales = Array.new
				Dir.glob(File.join(Gem.loaded_specs['rails-i18n'].full_gem_path, 'rails', 'locale', "*.yml")).each { |file|
					locale = File.basename(file, '.yml')
					locales << locale unless locale.length < 2 || locale.length > 3
				}
				locales
			end

			# Returns a list of locales that are ready for production
			# Each locale must meet a minimum completion percentage which can be set by config.language_threshold
			# The threshold is measured by the total number of keys avilable for translation divided by the total
			#  number of keys that have translations for each locale
			def enabled_locales
				@@enabled_locales ||= nil
				if !@@enabled_locales
					@@enabled_locales = Array.new
					available_locales.each { |locale|
						if (can_translate? && File.exists?("config/locales/#{locale}.yml")) || locale_enabled?(locale)
							@@enabled_locales << locale
						end
					}
				end
				@@enabled_locales
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

				# return 0 if we haven't got all of our base translations in
				#return 0.0 if _get_language_completion(locale, lingua_franca_translation_info(locale)) < 100
				return 0.0 unless File.exists?("config/locales/#{locale}.yml")

				# return the percentage of translations in use
				@@language_completion[locale] = _get_language_completion(locale, translation_info(locale))

			end

			# Determines if a locale is production ready and can be seen by any visitor
			# The default locale is always available, all other locales are measured for completion
			#  and compared against config.language_threshold to make sure the amount of translations
			#  available meet the minimum requirements
			def locale_enabled?(locale)
				locale.to_s == I18n.default_locale.to_s || get_language_completion(locale) >= I18n.config.language_threshold
			end

			def add_translation(locale, data, options = {})
				load_translations
				store_translations(locale, data, options)
				write_translations(locale.to_s, {locale => translations[locale.to_sym].deep_stringify_keys})
				save_change(locale, data)
				reset_stats!
				load_translations
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
				get_translation_info().each { |key, value|
					info[key] = value
					#info[key][:value] = lookup ? I18n.t(key, :locale => locale, :resolve => false, :throw => true) : nil
					info[key][:value] = nil
					if lookup
						catch(:exception) do
							info[key][:value] = lookup_raw(locale, key)
						end
					end
					if info[key][:value].is_a?(Array)
						info[key][:value] = Hash[[*info[key][:value].map.with_index]].invert
						info[key][:array] = true
					end
					info[key]['pages'] = value['pages'] ? value['pages'].collect { |page| get_route(page) } : []
				}
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
					:y => I18n.t('translate.datetime.year_two_digit', :context => 'year (00-99)'),
					:Y => I18n.t('translate.datetime.year_four_digit', :context => 'year ####'),
					:b => I18n.t('translate.datetime.month_abbr', :context => 'month abbr'),
					:B => I18n.t('translate.datetime.month_name', :context => 'month name'),
					:m => I18n.t('translate.datetime.month_two_digit', :context => 'month (01-12)'),
					:a => I18n.t('translate.datetime.weekday_abbr', :context => 'weekday abbr'),
					:A => I18n.t('translate.datetime.weekday_name', :context => 'weekday'),
					:e => I18n.t('translate.datetime.day', :context => 'day (1-31)'),
					:d => I18n.t('translate.datetime.day_padded', :context => 'day (01-31)'),
					:p => I18n.t('translate.datetime.AMPM', :context => 'AM/PM'),
					:P => I18n.t('translate.datetime.ampm', :context => 'am/pm'),
					:l => I18n.t('translate.datetime.hour_12', :context => 'hour (1-12)'),
					:k => I18n.t('translate.datetime.hour_24', :context => 'hour (0-23)'),
					:I => I18n.t('translate.datetime.hour_12_padded', :context => 'hour (01-12)'),
					:H => I18n.t('translate.datetime.hour_24_padded', :context => 'hour (00-23)'),
					:M => I18n.t('translate.datetime.minute', :context => 'minute (00-59)'),
					:S => I18n.t('translate.datetime.second', :context => 'second'),
					:z => I18n.t('translate.datetime.timezone_offset', :context => 'timezone offset'),
					:Z => I18n.t('translate.datetime.timezone_abbr', :context => 'timezone abbr')
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

			def concerns()
				concern_list = Array.new
				all_translation_info(I18n.default_locale, false).keys.each { |key|
					concern_list |= [key.split('.').first]
				}
				concern_list
			end

			def pages()
				page_list = Array.new
				translation_info(I18n.default_locale, false).each { |key, value|
					if value.has_key?('pages')
						value['pages'].each { |page|
							page_list << page unless page.nil? || page_list.include?(page)
						}
					end
				}
				page_list
			end

			def translation_info_for_concern(concern, locale = I18n.locale)
				info = Hash.new
				all_translation_info(locale).each { |key, value|
					info[key] = value if (concern == key.split('.').first)
				}
				info
			end

			def translation_info_for_page(page, locale = I18n.locale)
				info = Hash.new
				all_translation_info(locale).each { |key, value|
					info[key] = value if ((page == nil && !value.has_key?('pages')) || (value.has_key?('pages') && value['pages'].collect{|p|p.nil? ? nil : p[:path]}.include?(page)))
				}
				info
			end

			def undefined_translation_info(locale = I18n.locale)
				info = Hash.new
				all_translation_info(locale).each { |key, value|
					info[key] = value if value[:value].nil?
				}
				info
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
				context
			end

			def expand_data(data)
				new_data = {}
				data.each { |key, value|
					new_data.merge! expand_keys(key.split('.'), value)
				}
				new_data
			end

			def _(key, context = nil, context_size = nil, vars: {}, &block)#, html: nil, blockData: {}, &block)
				options = vars
				options[:fallback] = true
				if context
					options[:context] = context
					options[:context_size] = context_size
				end
				I18n.translate(key, options)
			end

			def _!(contents, &block)
				(contents || yield) unless translations_blocked
			end

			def push(*args)
				@stack ||= Array.new
				@stack.push(_(*args))
			end

			def pop()
				@stack.pop
			end

			def html_wrapper(*args, &block)
				return ['', ''] unless can_translate? || @@testing_started

				options  = args.last.is_a?(Hash) ? args.pop.dup : {}
				scope    = options.has_key?(:scope) ? options[:scope] : []
				locale   = options.has_key?(:locale) ? options[:locale] : I18n.locale
				key      = args.shift
				exists   = true

				if key.is_a?(Array)
					keys = Array.new
					key.each { |k| exists &= I18n.t(key, :locale => locale.to_sym, :resolve => false).present?; keys << key_name(k, scope) }
					key = keys
				else
					key = key_name(key, scope)
					exists = I18n.t(key, :locale => locale.to_sym, :resolve => false).present?
				end

				data = {
					'key' 				=> key.is_a?(Array) ? nil : key,
					'keys' 				=> key.is_a?(Array) ? key.join(',') : nil,
					'needs-translation'	=> exists ? 0 : 1,
					'context'			=> get_context(options[:context])
				}

				should_wrap_translation?(exists) ?
					[
						'<span class="translated-content' + (block_given? ? 'block' : '') + '"' + data.map{|k,v| v ? " data-i18n-#{k}=\"#{v}\"" : ''}.join('') + '>',
						'</span>'
					] :
					['', '']
			end

			def wrap(html, *args, &block)
				outer = html_wrapper(*args, &block)
				(outer.first + (html.nil? ? I18n.t(*args) : html) + outer.last).html_safe
			end

			def should_wrap_translation?(translation_exists)
				(can_translate? && !translation_exists) || @@testing_started
			end

			def can_translate?
				translator = I18n.config.translator
				translator.present? && translator.can_translate?
			end

			def current_page
				page_info[:path] ? get_route(page_info[:path])[:path] : nil
			end

			def page_needs_translations?(page = nil)
				page ||= get_route(page_info[:path])[:path]
				translation_info_for_page(page).each  { |key, value|
					return true if value[:value].nil?
				}
				false
			end

			def set_html(html)
				@@lingua_franca_html = html
			end

			protected
				def _get_language_completion(locale, _translation_info)
					total = 0
					complete = 0

					_translation_info.each { |key, info|
						if info[:value].is_a?(Hash)
							pluralization_rules(locale).each { |rule|
								if rule.to_sym == :one || rule.to_sym == :other
									total += 1
									complete += 1 unless info[:value].nil? || !info[:value].has_key?(rule) || info[:value][rule].nil?
								end
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

				def page_info
					@@page_info ||= {}
				end

				def write_translations(file, data)
					File.open("config/locales/#{file}.yml", 'w+') { |f| f.write data.to_yaml }
				end

				#def translation_cache
				#	@@translation_cache ||= {}
				#end

				# Looks up the translation and makes a record of it if we're currently testing
				# Returns the translation or if the translation is missing it will use
				#  options[:context] to determine what to return
				def lookup(locale, key, scope = [], options = {})
					return '' if translations_blocked

					result = super(locale, key, scope, options)

					key = key_name(key, scope)

					record_translation(locale.to_s, key, options, result) if should_make_record?(scope, options)

					result
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
				def should_make_record?(scope = [], options = {})
					ENV["RAILS_ENV"] == 'test' &&
						(!options.has_key?(:resolve) || options[:resolve])
				end

				def record_translation(locale, key, options, translation)
					# add the translation info
					data = get_translation_info()
					data[key] ||= Hash.new
					data[key]['pages'] ||= Array.new
					if options[:context]
						data[key]['context'] ||= options[:context].to_s
					end

					# add vars so that we can use them later to help the user translate
					vars = []
					options.each { |o,v|
						if !I18n::RESERVED_KEYS.include?(o.to_sym) && o.to_s != 'context' && o.to_s != 'context_size'
							vars << o.to_sym
						end
					}

					if vars.size() > 0
						data[key]['vars'] = vars
					end

					# add the route so that the translator has some context
					route = current_page
					unless route.nil? || data[key]['pages'].include?(route)
						data[key]['pages'] << route
					end

					@@request_id ||= 0
					@@last_request_id ||= nil
					if @@last_request_id != @@request_id
						@@lingua_franca_html ||= nil
						stop_recording_html
						set_page_name(page_info[:path].gsub(/^\/?(.*?)\.?/, '\1').gsub('/', '.'))
					end
					@@last_request_id = @@request_id

					@@page_name ||= nil
					if @@page_name.present?
						data[key]['examples'] ||= Array.new
						data[key]['examples'] << @@page_name
					end

					@@last_url = page_info[:path]

					# write them to the info DB
					write_translation_info(data)
					translation
				end

				def get_route(path)
					Rails.application.routes.routes.each { |r|
						if r.path.match(path)
							return {:name => r.name, :path => r.path.spec.to_s.gsub(/\s*\(\.:\w+\)\s*$/, '')}
						end
					}
					return path
				end

				def write_translation_info(translations)
					File.open(I18n.config.info_file, 'w') { |f| f.write translations.to_yaml }
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

