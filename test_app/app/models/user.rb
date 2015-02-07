class User < ActiveRecord::Base
	acts_as_translator
	has_many :blogs

	def can_translate?
		@@translating ||= false
	end

	def translating=(do_translate)
		@@translating = do_translate
	end
end
