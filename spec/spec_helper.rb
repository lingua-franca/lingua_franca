require 'bundler/setup'
Bundler.setup

require 'rails'
# There's a bug in the current version of active_model, this fixes it
if !defined?(Rails.env)
	module Rails
		def env
			return ENV["RAILS_ENV"]
		end
	end
end

require 'lingua_franca'

module LinguaFrancaHelperMock
	include LinguaFrancaHelper

	def _init!
	end
end

class LinguaFrancaMock < I18n::Backend::LinguaFranca
	@@mocked_cache

	def translation_info=(translation_info)
		@@translation_info = translation_info
	end

	def get_translation_info()
		@@translation_info ||= {}
	end

	# def set_cache(hash)
	# 	@@mocked_cache = hash
	# end

	# def retrieve_cache!
	# 	@@mocked_cache ||= super
	# end

	# def add_translations(translations)
	# 	filenames.flatten.each { |filename| load_file(filename) if languages.has_key?(File.basename(filename)) }
	# end

	def write_translations(data)
		@@translation_info = data
	end

	def set_translations(data)
		reload!
		data.each { |locale, d|
			locale = locale.to_sym
			translations[locale] ||= {}
			translations[locale].deep_merge!(d.deep_symbolize_keys)

			I18n.with_locale(locale) do
				hash_keys_to_strings(d).each { |key|
					I18n.t!(key)
				}
			end
		}
	end

	def get_route(path)
		return get_path || path
	end

	def path=(p)
		@@path = p
	end

	def get_path
		@@path ||= nil
	end

	def should_make_record?(scope = [], options = {})
		return (options[:context].to_s != 'strict')
	end

	def last_write
		@@last_write ||= nil
	end

	private
		def hash_keys_to_strings(hash, prefix = nil)
			if hash.is_a?(Hash)
				keys = Array.new
				hash.each { |key, value|
					keys += hash_keys_to_strings(value, prefix ? "#{prefix}.#{key}" : key)
				}
				return keys
			else
				return ["#{prefix}"]
			end
		end

		def write_translations(file, data)
			@@last_write = {:file => file, :data => data}
		end
end

RSpec.configure do |config|
	
	config.include LinguaFrancaHelper

	def init(test_object = nil)
		I18n.backend = LinguaFrancaMock.new
		ActionView::Base.send :include, LinguaFrancaHelperMock
		@test_object = test_object || ActionView::Base.new
		@test_object._init!
	end

	def render(string)
		ActionView::Template::Handlers::Erubis.new(string).evaluate(@test_object).gsub(/[\n\t]/, '').gsub(/>\s+</, '><')
	end

	def test_test_app
		output = ''
		Bundler.with_clean_env do
			Dir.chdir('test_app') do
				@last_test_output = `bundle exec rspec`
			end
		end
		@last_test_output
	end

	def expect_tests_to_pass!
		expect(@last_test_output || '').to match(/\n\d+ examples?, 0 failures\n/)
	end

	def translation_info_file
		@translation_info_file ||= 'test_app\config\locales\translation-info.yml'
	end

	def translation_cache_file
		@translation_cache_file ||= 'test_app\config\locales\translation-cache.yml'
	end
	
	def translation_info
		YAML.load_file(translation_info_file)
	end

	def set_translations(translations)
		File.open(translation_cache_file, 'w') { |f| f.write translations.to_yaml }
	end
end
