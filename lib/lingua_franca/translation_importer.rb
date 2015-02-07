require 'net/ftp'
require 'zip'
require 'open-uri'
require 'json'

require 'lingua_franca'



require 'forgery'

module LinguaFranca
	module TranslationImporter
		class << self

			def import! (backend = I18n::Backend::LinguaFranca.new)
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

			def import_languages locales
				Net::FTP.open('unicode.org', 'anonymous', '') do |ftp|
					ftp.chdir('Public/cldr')
					latest_version = ftp.list("-d -t */")[0].match(/:\d\d\s(.*?)\/?$/)[1]
					ftp.chdir(latest_version)

					file_to_get = 'json.zip'
					destination_file = file_to_get.gsub(/\.zip/, "-#{latest_version}.zip")

					if !File.exists?(destination_file)
						puts "Downloading latest translations: version #{latest_version}..."
						ftp.get(file_to_get, destination_file)
					else
						puts "Latest translations already downloaded: version #{latest_version}."
					end

					puts "Unzipping data..."

					data = {}

					Zip::File.open(destination_file) do |zipfile|
						zipfile.each do |file|
							if /main\/(\w+)\/languages\.json/ =~ file.to_s
								locale = Regexp.last_match(1)
								if locales.include?(locale)
									translations = YAML.load(file.get_input_stream.read)
									data[locale] = {'languages' => {}}
									translations['main'][locale]['localeDisplayNames']['languages'].each { |lang, translation|
										if locales.include?(lang)
											data[locale]['languages'][lang] = translation
										end
									}
								end
							end
						end
					end

					save_data('languages', data)
				end
			end

			protected

				def save_data(file, data)
					File.open(File.join(File.expand_path('../../..', __FILE__), "config/locales/#{file}.yml"), 'w') { |f| f.write data.to_yaml }
				end
		end
	end
end
