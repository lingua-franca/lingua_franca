require "spec_helper"

describe 'lingua franca backend tests' do
	before(:each) do
		I18n.backend = LinguaFrancaMock.new
		#translation_info_file
	end

	describe 'translate' do
		it "test" do
			#I18n.backend.initialize
			#I18n.backend.load_translations
			#expect('Nova Scotia').to eq(I18n.t('geography.subregions.CA.NS', {:raise => false}))
			puts I18n.backend.pluralization_rules(:en)
		end

	# 	it 'translates when the translation exists' do
	# 		I18n.config.locale = :en
	# 		expected = 'This our site, welcome!'
	# 		I18n.backend.set_translations({:en => {:home_page => {:Welcome_to_our_Site => expected}}})
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})

	# 		expect(actual).to eq(expected)
	# 	end

	# 	it 'contains country data by default' do
	# 		I18n.backend.set_translations({:en => {:home_page => {:Welcome_to_our_Site => 'This our site, welcome!'}}})

	# 		I18n.config.locale = :en
	# 		expect('China').to eq(I18n.t('geography.countries.CN', {:raise => false}))
	# 		expect('Nova Scotia').to eq(I18n.t('geography.subregions.CA.NS', {:raise => false}))

	# 		I18n.config.locale = :fr
	# 		expect('Chine').to eq(I18n.t('geography.countries.CN', {:raise => false}))
	# 		expect('Nouvelle-Écosse').to eq(I18n.t('geography.subregions.CA.NS', {:raise => false}))
	# 	end

	# 	it 'contains language data by default' do
	# 		I18n.backend.set_translations({:en => {:home_page => {:Welcome_to_our_Site => 'This our site, welcome!'}}})

	# 		I18n.config.locale = :en
	# 		expect('English').to eq(I18n.t('languages.en', {:raise => false}))

	# 		I18n.config.locale = :fr
	# 		expect('anglais').to eq(I18n.t('languages.en', {:raise => false}))
	# 	end

	# 	it 'pluralizes when the translation exists' do
	# 		I18n.config.locale = :en
	# 		I18n.backend.set_translations({:en => {:home_page => {
	# 			:nth_visitor => {
	# 				:one => 'You are our first visitor',
	# 				:other => 'You are number %{count}!'
	# 			}
	# 		}}})
	# 		actual = I18n.t('home_page.nth_visitor', {:raise => false, :count => 3})

	# 		expect(actual).to eq('You are number 3!')
	# 	end

	# 	it 'pluralizes singular when the translation exists' do
	# 		I18n.config.locale = :en
	# 		I18n.backend.set_translations({:en => {:home_page => {
	# 			:nth_visitor => {
	# 				:one => 'You are our first visitor',
	# 				:other => 'You are number %{count}!'
	# 			}
	# 		}}})
	# 		actual = I18n.t('home_page.nth_visitor', {:raise => false, :count => 1})

	# 		expect(actual).to eq('You are our first visitor')
	# 	end

	# 	it 'uses variables correctly' do
	# 		I18n.config.locale = :en
	# 		I18n.backend.set_translations({:en => {:home_page => {
	# 			:Welcome_to_our_Site => 'Welcome %{username}!'
	# 		}}})
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false, :username => 'Cookie Monster'})

	# 		expect(actual).to eq('Welcome Cookie Monster!')
	# 	end

	# 	it 'uses last key as translation when translation is missing' do
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		expected = 'Welcome to our Site'

	# 		expect(actual).to eq(expected)
	# 	end

	# 	it 'uses last key when translation is missing for current locale' do
	# 		I18n.backend.set_translations(
	# 			{
	# 				:en => {:home_page => {:Welcome_to_our_Site => 'This our site, welcome!', :some_other_key => 'whatever'}},
	# 				:fr => {:home_page => {:some_other_key => 'something in french', :another_key => 'something else in french'}}
	# 			}
	# 		)
	# 		I18n.config.locale = :fr
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		expected = 'Welcome to our Site'

	# 		expect(actual).to eq(expected)
	# 	end

	# 	it 'uses last key when translation is missing for current locale' do
	# 		I18n.backend.set_translations(
	# 			{
	# 				:en => {:home_page => {:Welcome_to_our_Site => 'This our site, welcome!', :some_other_key => 'whatever'}},
	# 				:fr => {:home_page => {:some_other_key => 'something in french', :another_key => 'something else in french'}}
	# 			}
	# 		)
	# 		I18n.config.locale = :fr
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		expected = 'Welcome to our Site'

	# 		expect(actual).to eq(expected)
	# 	end

	# 	it 'returns a random word when context is :word and translation is missing' do
	# 		actual = I18n.t('home_page.a_single_word', {:context => :word, :raise => false})

	# 		expect(actual).to match(/^\w+$/)
	# 	end

	# 	it 'returns a random word when context is :w and translation is missing' do
	# 		actual = I18n.t('home_page.a_single_word', {:context => :w, :raise => false})

	# 		expect(actual).to match(/^\w+$/)
	# 	end

	# 	it 'returns a random word when context is word and translation is missing' do
	# 		actual = I18n.t('home_page.a_single_word', {:context => 'word', :raise => false})

	# 		expect(actual).to match(/^\w+$/)
	# 	end

	# 	it 'returns two random words when context is :word and word size is 2 and translation is missing' do
	# 		actual = I18n.t('home_page.two_words', {:context => :word, :context_size => 2, :raise => false})

	# 		expect(actual).to match(/^\w+\s[a-z]\w*$/)
	# 	end

	# 	it 'returns title case words when context is :title and translation is missing' do
	# 		actual = I18n.t('home_page.a_title', {:context => :title, :raise => false})

	# 		# A title should have all word capitalized, not end in a period but might have commas
	# 		#  or other non-word characters between words
	# 		expect(actual).to match(/^([A-Z]\w*\W?\s)*[A-Z]\w*$/)
	# 	end
	# end

	# describe 'add translations' do
	# 	it 'writes to file' do
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		old_translation = 'Welcome to our Site'

	# 		expect(actual).to eq(old_translation)

	# 		new_translation = 'This is our site!'
	# 		I18n.backend.add_translation(:en, {:home_page => { 'Welcome_to_our_Site' => new_translation } })

	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		expect(actual).to eq(new_translation)
	# 		expect(I18n.backend.last_write[:file]).to eq('en')
	# 		expect(I18n.backend.last_write[:data]).to have_key(:en)
	# 		expect(I18n.backend.last_write[:data][:en]).to have_key(:home_page)
	# 		expect(I18n.backend.last_write[:data][:en][:home_page]).to have_key(:Welcome_to_our_Site)
	# 		expect(I18n.backend.last_write[:data][:en][:home_page][:Welcome_to_our_Site]).to eq(new_translation)
	# 		expect(I18n.backend.get_language_completion(:en)).to eq(100.0)
	# 		expect(I18n.backend.get_language_completion(:fr)).to eq(0.0)
	# 	end

	# 	it 'resets stats' do
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		old_translation = 'Welcome to our Site'

	# 		expect(actual).to eq(old_translation)

	# 		new_translation = 'This is our site!'
	# 		I18n.backend.add_translation(:en, {:home_page => { 'Welcome_to_our_Site' => new_translation } })

	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		expect(actual).to eq(new_translation)

	# 		expect(I18n.backend.get_language_completion(:en)).to eq(100.0)
	# 		expect(I18n.backend.get_language_completion(:fr)).to eq(0.0)

	# 		fr_translation = 'Ce est notre site!'
	# 		I18n.backend.add_translation(:fr, {:home_page => { 'Welcome_to_our_Site' => fr_translation } })

	#  		I18n.config.locale = :fr
	# 		actual = I18n.t('home_page.Welcome_to_our_Site', {:raise => false})
	# 		expect(actual).to eq(fr_translation)

	# 		expect(I18n.backend.get_language_completion(:en)).to eq(100.0)
	# 		expect(I18n.backend.get_language_completion(:fr)).to eq(100.0)
	# 	end
	end
end
