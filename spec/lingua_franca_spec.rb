require "spec_helper"

describe LinguaFrancaHelper, :type => :helper do
	before(:each) do
		init
	end

	it 'uses last key as translation when translation is missing' do
		template =
		<<-TEMPLATE
		<%= _'home_page.Welcome_to_our_Site' %>
		TEMPLATE
		
		expected = 'Welcome to our Site'
		actual = render(template)

		expect(actual).to eq(expected)
	end
end
