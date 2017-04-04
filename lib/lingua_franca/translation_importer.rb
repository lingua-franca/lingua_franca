require 'net/ftp'
require 'zip'
require 'open-uri'
require 'json'
require 'forgery'

require 'lingua_franca'

module LinguaFranca
  module TranslationImporter
    class << self

      def import!(backend = I18n::Backend::LinguaFranca.new)
        locales = backend.available_locales
        import_languages locales
        import_geography locales
      end

      def config
        @@config ||= YAML.load_file(File.join(Dir.pwd, 'config', 'lingua_franca.yml')).deep_symbolize_keys || {}
      end

      def import_geography locales
        username = config[:importer][:geonames][:username]
        
        if username.blank?
          puts ""
          puts "Geography Importer Failed!"
          puts ""
          puts "\tA geonames user name has not yet been provided to that we can obtain"
          puts "\ta list of countries and regions"
          puts ""
          puts "\tIf you want to be able to get an updated list of countries and regions"
          puts "\tin all languages please create a username at http://www.geonames.org,"
          puts "\tenable the api and put the username in config/franca_linga.yml"
          puts ""
          return
        end

        data = {}
        country_data = {}
        locales.each { |locale|
          locale = locale.to_s
          data[locale] = {'geography' => {'countries' => {}, 'subregions' => {}}}
          puts "Getting country info for #{locale} locale"
          JSON.parse(open("http://api.geonames.org/countryInfoJSON?lang=#{locale}&username=#{username}").read)['geonames'].each { |country|
            country_code = country['countryCode'];
            data[locale]['geography']['countries'][country_code] = country['countryName']

            if !country_data.has_key?(country_code)
              (JSON.parse(open("http://api.geonames.org/childrenJSON?geonameId=#{country['geonameId']}&username=#{username}&style=full").read)['geonames'] || []).each { |subregion|
                if subregion.has_key?('alternateNames')
                  subregion_data = {'default_name' => subregion['name']}
                  abbr = nil
                  subregion['alternateNames'].each {|names|
                    if names['lang'] == 'abbr'
                      abbr = names['name'].gsub(/\W/, '')
                    else
                      subregion_data[names['lang']] = names['name']
                    end
                  }
                  if abbr
                    country_data[country_code] ||= {}
                    country_data[country_code][abbr] = subregion_data
                  end
                end
              }
              country_data[country_code] ||= {}
            end
            country_data[country_code].each { |abbr, subregion|
              data[locale]['geography']['subregions'][country_code] ||= {}
              data[locale]['geography']['subregions'][country_code][abbr] = (subregion[locale] || subregion['default_name'])
            }
          }
        }
        save_data('geography', data)
      end

      def import_languages(locales)
        data = {}
        locales.each do |locale|
          locale = locale.to_s
          data[locale] = {'languages' => {}}
          github_url = "https://raw.githubusercontent.com/unicode-cldr/cldr-localenames-full/master/main/#{locale}/languages.json"
          puts "Downloading #{locale} data from #{github_url}"
          github_data = false
          begin
            github_data = open(github_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
          rescue
            puts "Error downloading #{locale} data"
          end
          if github_data
            JSON.parse(github_data.read)['main'][locale]['localeDisplayNames']['languages'].each do | language, translation |
              data[locale]['languages'][language] = translation
            end
          end
        end
        save_data('languages', data)
      end

      protected

        def save_data(file, data)
          File.open(File.join(File.expand_path('../../..', __FILE__), "config/locales/#{file}.yml"), 'w') { |f| f.write data.to_yaml }
        end
    end
  end
end
