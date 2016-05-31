require 'active_record'

module LinguaFranca
	module ActiveRecord
		def does_translate(column = nil)
			return false
		end

		def translates(*columns)
			class_eval <<-RUBY, __FILE__, __LINE__+1
				before_save :set_locale
				after_save :save_translations

				def set_locale
					self.locale ||= I18n.locale
				end
				
				def save_translations
					if I18n.config.callback.present? && @translatable_content_changed.present?
						I18n.config.callback.on_translatable_content_change(self, @translatable_content_changed)
						@translatable_content_changed = nil
					end

					return unless @pending_translations.present?
					
					data = {}
					loc = @pending_translations.first.locale
					translator_id = @pending_translations.first.translator_id

					@pending_translations.each { |translation|
						data[translation.column] = {
							old: send(('_' + translation.column).to_sym, loc),
							new: translation.value
						}
					}
					I18n.config.callback.on_translation_change(self, data, loc, translator_id) if I18n.config.callback.present?
					@pending_translations.each { |translation|
						translation.model_id = send(:id)
						translation.save
					}
					@pending_translations = nil
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

				def get_translators_for_column_and_locale(column, loc)
					DynamicTranslationRecord.where(
							locale: loc,
							model_type: send(:class).table_name,
							model_id: send(:id),
							column: column.to_s
						).uniq.pluck(:translator_id)
				end

				def get_translators_for_column(column)
					DynamicTranslationRecord.where(
							model_type: send(:class).table_name,
							model_id: send(:id),
							column: column.to_s
						).uniq.pluck(:translator_id)
				end

				def set_column_for_locale(column, loc, value, translator_id = nil)
					@pending_translations ||= []
					@pending_translations << DynamicTranslationRecord.new(
							locale: loc.to_s,
							translator_id: translator_id || I18n.config.translator_id,
							model_type: self.class.table_name,
							column: column,
							value: value
						)
				end

				def requires_translation?
					#{columns.collect{|c| c.to_s + '_requires_translation?'}.join(' && ')}
				end

				def does_translate(column = nil)
					return true if column.nil?
					return columns.include?(column.to_sym)
				end

				def original_content_changed(column, value)
					old_value = send(column)
					return if old_value == value
					
					@translatable_content_changed ||= {}
					@translatable_content_changed[column] = { old: old_value, new: value }
				end
			RUBY

			columns.each { |column|
				class_eval <<-RUBY, __FILE__, __LINE__+1

					def #{column}
						return '' if I18n.backend.translations_blocked
						user_locale = I18n.locale.to_s
						l = send(:locale).to_s
						if l.blank? || l == user_locale
							return super
						end
						record = get_column_for_locale(:#{column}, user_locale)
						record ? record.value : super
					end

					def _#{column}(loc)
						return '' if I18n.backend.translations_blocked
						l = send(:locale).to_s
						if l.blank? || l == loc.to_s
							return #{column}
						end
						record = get_column_for_locale(:#{column}, loc)
						record ? record.value : nil
					end

					def #{column}_requires_translation?
						get_column_for_locale(:#{column}, I18n.locale).nil?
					end
					
					def #{column}!
						return '' if I18n.backend.translations_blocked
						get_column_for_locale(:#{column}, locale)
					end

					def #{column}=(value)
						l = send(:locale).to_s
						if l.blank? || l == I18n.locale.to_s
							original_content_changed(:#{column}, value)
							return super(value)
						end
						set_column_for_locale(:#{column}, I18n.locale, value)
					end
				RUBY
			}
		end

		def acts_as_translator
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
