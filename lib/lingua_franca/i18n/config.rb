module I18n
	class Config
		def cache_file
			@@translation_cache_file ||= 'config/locales/data/translation-cache.yml'
		end

		def cache_file=(cache_file)
			@@translation_cache_file = cache_file
		end

		def info_file
			@@translation_info_file ||= 'config/locales/data/translation-info.yml'
		end

		def html_records_dir
			@@html_records_dir ||= 'config/locales/data/html_records'
		end

		def html_records_dir=(html_records_dir)
			@@html_records_dir = html_records_dir
		end

		def info_file=(info_file)
			@@translation_info_file = info_file
		end

		def languages_file
			@@translation_languages_file ||= File.join(File.expand_path('../../../..', __FILE__), 'config/locales/languages.yml')
		end

		def languages_file=(languages_file)
			@@translation_languages_file = languages_file
		end

		def geography_file
			@@translation_geography_file ||= File.join(File.expand_path('../../../..', __FILE__), 'config/locales/geography.yml')
		end

		def geography_file=(geography_file)
			@@translation_geography_file = geography_file
		end

		# the percentage of translations that must exist for a given language in order for it to be enabled
		def language_threshold
			@@language_threshold ||= 80
		end

		def language_threshold=(language_threshold)
			@@language_threshold = language_threshold
		end

		def translator
			@@current_translator ||= nil
		end
		
		def translator=(user)
			@@current_translator = user
		end

		# the id of the current translator, used for recording changes in translations
		def translator_id
			translator.nil? ? nil : translator.id
		end

		# the name of the model used for recording chanes to translations
		def translation_model
			@@translation_model ||= nil
		end

		def translation_model=(model_class)
			@@translation_model = model_class
		end

		# the number of sentences in lorem ipsum generated paragraphs
		def default_paragraph_length
			@@default_paragraph_length ||= 10
		end

		def default_paragraph_length=(default_paragraph_length)
			@@default_paragraph_length = default_paragraph_length
		end

		DETECT_LANGUAGE_FROM_URL_PARAM = 1 # http://example.com/?lang=fr
		DETECT_LANGUAGE_FROM_SUBDOMAIN = 2 # http://fr.example.com/
		DETECT_LANGUAGE_FROM_SUBDIR    = 3 # http://example.com/fr/
		DETECT_LANGUAGE_FROM_TOP_LEVEL = 4 # http://example.fr/

		# the method used for setting the current language form a url
		def language_detection_method
			# the default is DETECT_LANGUAGE_FROM_URL_PARAM because its the easiest
			#  however the recommended is subdomain
			@@language_detection_method ||= DETECT_LANGUAGE_FROM_URL_PARAM
		end

		def language_detection_method=(language_detection_method)
			@@language_detection_method = language_detection_method
		end

		# the method used for setting the current language form a url
		def language_url_param
			@@language_url_param ||= 'lang'
		end

		def language_url_param=(language_url_param)
			@@language_url_param = language_url_param
		end

		def host_locale_regex
			@@host_locale_regex ||= /^([a-z]{2})\.[^\.]+\..*$/
		end

		def host_locale_regex=(host_locale_regex)
			@@host_locale_regex = host_locale_regex
		end
	end
end
