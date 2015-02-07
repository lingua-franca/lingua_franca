require 'active_record'

module LinguaFranca
	module ActiveRecord
		def translates(*columns)
			class_eval <<-RUBY, __FILE__, __LINE__+1
				before_save :set_locale
				after_save :save_translations

				def set_locale
					self.locale ||= I18n.locale
				end
				
				def save_translations
					@@pending_translations ||= {}
					@@pending_translations.each { |translation|
						translation.model_id = send(:id)
						translation.save
					}
					@@pending_translations = nil
				end

				def get_column_for_locale(column, loc)
					loc = loc.to_s
					return self.send(column) if loc == locale
					DynamicTranslationRecord.where(
							locale: loc,
							model_type: send(:class).table_name,
							model_id: send(:id),
							column: column.to_s
						).order('created_at DESC').limit(1).first
				end

				def requires_translation?
					#{columns.collect{|c| c.to_s + '_requires_translation?'}.join(' && ')}
				end
			RUBY

			columns.each { |column|
				class_eval <<-RUBY, __FILE__, __LINE__+1

					def #{column}
						user_locale = I18n.locale.to_s
						l = send(:locale).to_s
						if l.blank? || l == user_locale
							return super
						end
						record = get_column_for_locale(:#{column}, user_locale)
						record ? record.value : super
					end

					def #{column}_requires_translation?
						get_column_for_locale(:#{column}, I18n.locale).nil?
					end
					
					def #{column}!
						get_column_for_locale(:#{column}, locale)
					end

					def #{column}=(value)
						l = send(:locale).to_s
	          			if l.blank? || l == I18n.locale.to_s
	          				return super(value)
	          			end
	          			@@pending_translations ||= []
	          			@@pending_translations << DynamicTranslationRecord.new(
	          				locale: I18n.locale.to_s,
	          				translator_id: I18n.config.translator_id,
	          				model_type: self.class.table_name,
	          				column: '#{column}',
	          				value: value
	      				)
	        		end
				RUBY
			}
		end
		def acts_as_translator
			#if !self.respond_to?(:id)
			#class_eval <<-RUBY, __FILE__, __LINE__+1
			#	def id
			#		0
			#	end
			#RUBY
			#end

			if !self.respond_to?(:can_translate?)
			class_eval <<-RUBY, __FILE__, __LINE__+1
				def can_translate?
					false
				end
			RUBY
			end
		end
	end
end

ActiveRecord::Base.extend LinguaFranca::ActiveRecord
