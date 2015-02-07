#require 'spec_helper'
require 'factory_girl'

DatabaseCleaner.strategy = :truncation

FactoryGirl.define do
	factory :blog do
		id      1
		title   'My First Blog Post'
		content 'Hi, welcome to my blog. Here I will write all sorts of interesting things.'
		locale  'en'
	end

	factory :blog_title, class: DynamicTranslationRecord do
    	locale        'fr'
    	translator_id 0
    	model_type    'blogs'
    	model_id      1
    	column        'title'
    	value         'Mon premier blog'
    	created_at    DateTime.now - 2.days
	end

	factory :blog_content, class: DynamicTranslationRecord do
    	locale        'fr'
    	translator_id 0
    	model_type    'blogs'
    	model_id      1
    	column        'content'
    	value         'Salut, bienvenue sur mon blog. Ici, je vais écrire toutes sortes de choses intéressantes.'
    	created_at    DateTime.now - 2.days
	end

	factory :blog_content_replacement, class: DynamicTranslationRecord do
    	locale        'fr'
    	translator_id 0
    	model_type    'blogs'
    	model_id      1
    	column        'content'
    	value         'Bonjour, bienvenue sur mon site. Ici, je vais composer toutes sortes de objects curieux.'
    	created_at    DateTime.now
	end
end

RSpec.describe Blog, :type => :model do
	before(:each) do
		DatabaseCleaner.clean
	end

	describe 'get translation' do
		it 'shows default english translation' do
			post = FactoryGirl.create(:blog)

			expect(post.title).to eq 'My First Blog Post'
			expect(post.content).to eq 'Hi, welcome to my blog. Here I will write all sorts of interesting things.'
		end

		it 'shows default english translation if locale is fr and no translations exist' do
			I18n.locale = :fr
			post = FactoryGirl.create(:blog)

			expect(post.title).to eq 'My First Blog Post'
			expect(post.content).to eq 'Hi, welcome to my blog. Here I will write all sorts of interesting things.'
		end

		it 'shows french title if locale is fr' do
			I18n.locale = :fr
			post = FactoryGirl.create(:blog)
			FactoryGirl.create(:blog_title)

			expect(post.title).to eq 'Mon premier blog'
			expect(post.content).to eq 'Hi, welcome to my blog. Here I will write all sorts of interesting things.'
		end

		it 'shows french title and content if locale is fr' do
			I18n.locale = :fr
			post = FactoryGirl.create(:blog)
			FactoryGirl.create(:blog_title)
			FactoryGirl.create(:blog_content)

			expect(post.title).to eq 'Mon premier blog'
			expect(post.content).to eq 'Salut, bienvenue sur mon blog. Ici, je vais écrire toutes sortes de choses intéressantes.'
		end

		it 'uses latest content' do
			I18n.locale = :fr
			post = FactoryGirl.create(:blog)
			FactoryGirl.create(:blog_title)
			FactoryGirl.create(:blog_content)
			FactoryGirl.create(:blog_content_replacement)

			expect(post.title).to eq 'Mon premier blog'
			expect(post.content).to eq 'Bonjour, bienvenue sur mon site. Ici, je vais composer toutes sortes de objects curieux.'
		end

		it 'updates as expected' do
			I18n.locale = :fr
			post = FactoryGirl.create(:blog)
			FactoryGirl.create(:blog_title)
			FactoryGirl.create(:blog_content)
			FactoryGirl.create(:blog_content_replacement)

			post.title = 'Mon initial blog'
			post.save!

			expect(post.title).to eq 'Mon initial blog'
			expect(post.content).to eq 'Bonjour, bienvenue sur mon site. Ici, je vais composer toutes sortes de objects curieux.'
		end

		it 'sets default locale to en' do
			I18n.locale = :en
			post = Blog.new

			post.title = 'Mon initial blog'
			post.content = 'Some content'
			post.save!

			expect(post.locale).to eq 'en'
		end

		it 'sets default locale to fr' do
			I18n.locale = :fr
			post = Blog.new

			post.title = 'Mon initial blog'
			post.content = 'Some content'
			post.save!

			expect(post.locale).to eq 'fr'
		end
	end
end
