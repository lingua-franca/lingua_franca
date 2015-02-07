require "spec_helper"

describe "I18n tests" do
	before(:each) do
		I18n.config.cache_file = File.join(File.dirname(__FILE__), 'tmp/.translation-cache.yml')
		I18n.backend = LinguaFrancaMock.new
		I18n.backend.reload!
		I18n.backend.translation_info = {}
		I18n.default_locale = :en
		I18n.config.language_threshold = nil
	end

	describe "get_locale" do
		it "returns en for en.bikebike.org" do
			expect(I18n.backend.get_locale("http://en.bikebike.org")).to eq('en')
		end

		it "returns fr for fr.bikebike.org" do
			I18n.default_locale = :en
			expect(I18n.backend.get_locale("http://fr.bikebike.org")).to eq('fr')
		end

		it "returns en for https" do
			expect(I18n.backend.get_locale("https://en.bikebike.org")).to eq('en')
		end

		it "returns empty for bikebike.org" do
			expect(I18n.backend.get_locale("https://bikebike.org")).to eq('')
		end

		it "returns empty for www.bikebike.org" do
			expect(I18n.backend.get_locale("https://www.bikebike.org")).to eq('')
		end

		it "returns en for dev.en.bikebike.org" do
			expect(I18n.backend.get_locale("https://dev.en.bikebike.org")).to eq('en')
		end

		it "returns en for en.whatever.something.pizza" do
			expect(I18n.backend.get_locale("https://en.whatever.something.pizza")).to eq('en')
		end
	end

	describe "set_locale" do
		it "en.bikebike.org should set language to en" do
			I18n.backend.set_translations({
				:en => {
					'phrase1' => 'A phrase',
					'phrase2' => 'Another phrase'
				},
				:fr => {
					'phrase1' => 'Une phrase',
					'phrase2' => 'Une autre phrase'
				}
			})

			expect(I18n.backend.set_locale("http://en.bikebike.org")).to be true
			expect(I18n.locale).to eq(:en)
		end

		it "fr.bikebike.org should set language to fr" do
			I18n.backend.set_translations({
				:en => {
					'phrase1' => 'A phrase',
					'phrase2' => 'Another phrase'
				},
				:fr => {
					'phrase1' => 'Une phrase',
					'phrase2' => 'Une autre phrase'
				}
			})

			expect(I18n.backend.set_locale("http://fr.bikebike.org")).to be true
			expect(I18n.locale).to eq(:fr)
		end

		it "fr.bikebike.org should set language to en if en is default and fr is not available" do
			I18n.backend.set_translations({
				:en => {
					'phrase1' => 'A phrase',
					'phrase2' => 'Another phrase'
				}
			})

			I18n.default_locale = :en
			expect(I18n.backend.set_locale("http://fr.bikebike.org")).to be false
			expect(I18n.locale).to eq(:en)
		end

		it "en.bikebike.org should set language to fr if fr is default and en is not available" do
			I18n.backend.set_translations({
				:fr => {
					'phrase1' => 'Une phrase',
					'phrase2' => 'Une autre phrase'
				}
			})

			I18n.default_locale = :fr
			expect(I18n.backend.set_locale("http://en.bikebike.org")).to be false
			expect(I18n.locale).to eq(:fr)
		end
	end

	describe "get_language_completion" do
		it "should return 100% if all keys in same language" do
			I18n.backend.set_translations({:en => {
				'some_key' => { 'sub_key_1' => 'My Translation', 'sub_key_2' => 'Another Translation'},
				'another_key' => {'sub_key_3' => 'Yet Another Translation'}
			}})
			expect(I18n.backend.get_language_completion('en')).to eq(100.0)
			expect(I18n.backend.get_language_completion('fr')).to eq(0.0)
			expect(I18n.backend.locale_enabled?(:en)).to be true
			expect(I18n.backend.locale_enabled?(:fr)).to be false
			expect(I18n.backend.enabled_locales.length).to be 1
		end

		it "should return 0% for default language if no keys" do
			I18n.backend.set_translations({})
			expect(I18n.backend.get_language_completion('en')).to eq(0.0)
			expect(I18n.backend.get_language_completion('fr')).to eq(0.0)
			expect(I18n.backend.locale_enabled?(:en)).to be true
			expect(I18n.backend.locale_enabled?(:fr)).to be false
			expect(I18n.backend.enabled_locales.length).to be 1
		end

		it "should return 50% if half keys exist in french" do
			I18n.backend.set_translations({
				:en => {
					'some_key' => { 'sub_key_1' => 'My Translation', 'sub_key_2' => 'Another Translation'},
					'another_key' => {'sub_key_3' => 'Yet Another Translation', 'sub_key_4' => 'One more'}
				},
				:fr => {
					'some_key' => { 'sub_key_1' => 'Ma traduction'},
					'another_key' => {'sub_key_3' => 'Pourtant, une autre traduction'}
				}
			})
			expect(I18n.backend.get_language_completion('en')).to eq(100.0)
			expect(I18n.backend.get_language_completion('fr')).to eq(50.0)
			expect(I18n.backend.locale_enabled?(:en)).to be true
			expect(I18n.backend.locale_enabled?(:fr)).to be false
			expect(I18n.backend.enabled_locales.length).to be 1
		end

		it "should return 75% if three quarters of keys exist in french" do
			I18n.backend.set_translations({
				:en => {
					'some_key' => { 'sub_key_1' => 'My Translation', 'sub_key_2' => 'Another Translation'},
					'another_key' => {'sub_key_3' => 'Yet Another Translation', 'sub_key_4' => 'One more'}
				},
				:fr => {
					'some_key' => { 'sub_key_1' => 'Ma traduction', 'sub_key_2' => 'Une autre traduction'},
					'another_key' => {'sub_key_3' => 'Pourtant, une autre traduction'}
				}
			})
			expect(I18n.backend.get_language_completion('en')).to eq(100.0)
			expect(I18n.backend.get_language_completion('fr')).to eq(75.0)
			expect(I18n.backend.locale_enabled?(:en)).to be true
			expect(I18n.backend.locale_enabled?(:fr)).to be false
			expect(I18n.backend.enabled_locales.length).to be 1
		end

		it "french should be enabled if 75% complete and threshold is set to 75%" do
			I18n.backend.set_translations({
				:en => {
					'some_key' => { 'sub_key_1' => 'My Translation', 'sub_key_2' => 'Another Translation'},
					'another_key' => {'sub_key_3' => 'Yet Another Translation', 'sub_key_4' => 'One more'}
				},
				:fr => {
					'some_key' => { 'sub_key_1' => 'Ma traduction', 'sub_key_2' => 'Une autre traduction'},
					'another_key' => {'sub_key_3' => 'Pourtant, une autre traduction'}
				}
			})
			I18n.config.language_threshold = 75
			expect(I18n.backend.get_language_completion('en')).to eq(100.0)
			expect(I18n.backend.get_language_completion('fr')).to eq(75.0)
			expect(I18n.backend.locale_enabled?(:en)).to be true
			expect(I18n.backend.locale_enabled?(:fr)).to be true
			expect(I18n.backend.enabled_locales.length).to be 2
		end

		it "french should not be enabled if 75% complete and threshold is set to 76%" do
			I18n.backend.set_translations({
				:en => {
					'some_key' => { 'sub_key_1' => 'My Translation', 'sub_key_2' => 'Another Translation'},
					'another_key' => {'sub_key_3' => 'Yet Another Translation', 'sub_key_4' => 'One more'}
				},
				:fr => {
					'some_key' => { 'sub_key_1' => 'Ma traduction', 'sub_key_2' => 'Une autre traduction'},
					'another_key' => {'sub_key_3' => 'Pourtant, une autre traduction'}
				}
			})
			I18n.config.language_threshold = 76
			expect(I18n.backend.get_language_completion('en')).to eq(100.0)
			expect(I18n.backend.get_language_completion('fr')).to eq(75.0)
			expect(I18n.backend.locale_enabled?(:en)).to be true
			expect(I18n.backend.locale_enabled?(:fr)).to be false
			expect(I18n.backend.enabled_locales.length).to be 1
		end
	end
end
