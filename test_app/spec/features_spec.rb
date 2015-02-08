ENV["RAILS_ENV"] ||= 'test'

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'
require 'capybara/poltergeist'
require 'factory_girl'
require 'lingua_franca/capybara'

Capybara.configure do |c|
  c.run_server = true
  c.javascript_driver = :lingua_franca_poltergeist
  c.default_driver = :lingua_franca_poltergeist
end

RSpec.configure do |config|
  config.render_views
end

DatabaseCleaner.strategy = :truncation

class LinguaFrancaApplicationController
  def self.set_current_user(user_id)
    @@user_id = user_id
  end

  def session
    @@user_id ||= nil
    @@user_id.nil? ? {} : {:current_user => @@user_id}
  end
end

FactoryGirl.define do
  factory :fake_user, class: User do
    id      1
    name   'Username'
  end

  factory :fake_blog, class: Blog do
    id      1
    title   'Mon Premiere Post'
    content 'Hi, welcome to my blog. Here I will write all sorts of interesting things.'
    locale  'en'
    user_id 1
  end

  factory :fake_french_blog, class: Blog do
    id      2
    title   'Mon premier blog'
    content 'Salut, bienvenue sur mon blog. Ici, je vais écrire toutes sortes de choses intéressantes.'
    locale  'fr'
    user_id 1
  end
end

feature 'Home page' do
  before(:each) do
    DatabaseCleaner.clean
  end

  scenario 'user visits home page but is not logged in and there are no posts' do
    visit '/'
    expect(page).to have_css('input[value="login"]')
  end

  scenario 'user visits home page and sees a blog post but is not logged in' do
    user = FactoryGirl.create(:fake_user)
    post = FactoryGirl.create(:fake_blog)
    visit '/'
    expect(page).to have_css('input[value="login"]')
  end

  scenario 'logged in user user visits home page and sees a blog post' do
    user = FactoryGirl.create(:fake_user)
    post = FactoryGirl.create(:fake_blog)
    LinguaFrancaApplicationController::set_current_user(user.id)
    visit '/'
    expect(page).to have_css('input[value="logout"]')
  end

  scenario 'logged in user user visits home page and sees a blog post but it is not in English' do
    user = FactoryGirl.create(:fake_user)
    post = FactoryGirl.create(:fake_french_blog)
    LinguaFrancaApplicationController::set_current_user(user.id)
    visit '/'
    expect(page).to have_css('input[value="logout"]')
  end

  scenario 'logged in user translates a French blog post to English' do
    user = FactoryGirl.create(:fake_user)
    post = FactoryGirl.create(:fake_french_blog)
    LinguaFrancaApplicationController::set_current_user(user.id)
    visit '/translate_post/2'
    expect(page).to have_css('input[value="logout"]')
  end
end
