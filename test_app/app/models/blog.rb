class Blog < ActiveRecord::Base
	translates :title, :content
	belongs_to :user
end
