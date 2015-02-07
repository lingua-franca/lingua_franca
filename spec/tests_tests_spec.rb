require "spec_helper"

describe "Tests tests" do
	before(:each) do
		#I18n.config.cache_file = File.join(File.dirname(__FILE__), 'tmp/.translation-cache.yml')
		#I18n.backend = LinguaFrancaMock.new
	end

	it "creates info file" do
		set_translations({})
		
		test_test_app

		# we expect out tests to pass
		expect_tests_to_pass!
		expect(translation_info.length).to eq(2)

		expect(translation_info['home_page.Welcome_to_our_Site']['languages'].length).to eq(0)
		expect(translation_info['home_page.Welcome_to_our_Site']['pages'].length).to eq(1)
		expect(translation_info['home_page.Welcome_to_our_Site']['pages'].first).to eq('/')
		expect(translation_info['home_page.Welcome_to_our_Site']).not_to have_key('context')

		expect(translation_info['home_page.welcome_paragraph']['languages'].length).to eq(0)
		expect(translation_info['home_page.welcome_paragraph']['pages'].length).to eq(1)
		expect(translation_info['home_page.welcome_paragraph']['pages'].first).to eq('/')
		expect(translation_info['home_page.welcome_paragraph']).to have_key('context')
		expect(translation_info['home_page.welcome_paragraph']['context']).to eq('p')
	end

	it "records translations" do
		set_translations({
			'en' => {
				'home_page.Welcome_to_our_Site' => 'This site is the best!'
			}
		})

		test_test_app

		# we expect out tests to pass
		expect_tests_to_pass!
		expect(translation_info.length).to eq(2)

		expect(translation_info['home_page.Welcome_to_our_Site']['languages'].length).to eq(1)
		expect(translation_info['home_page.Welcome_to_our_Site']['languages'].first).to eq('en')
		expect(translation_info['home_page.Welcome_to_our_Site']['pages'].length).to eq(1)
		expect(translation_info['home_page.Welcome_to_our_Site']['pages'].first).to eq('/')
		expect(translation_info['home_page.Welcome_to_our_Site']).not_to have_key('context')

		expect(translation_info['home_page.welcome_paragraph']['languages'].length).to eq(0)
		expect(translation_info['home_page.welcome_paragraph']['pages'].length).to eq(1)
		expect(translation_info['home_page.welcome_paragraph']['pages'].first).to eq('/')
		expect(translation_info['home_page.welcome_paragraph']).to have_key('context')
		expect(translation_info['home_page.welcome_paragraph']['context']).to eq('p')
	end
end
