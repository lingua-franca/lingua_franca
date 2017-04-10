require 'forgery'

module I18n
  class LinguaFrancaMissingTranslation < ExceptionHandler
    def lorem_ipsum(context, size)
      options = { random: true }
      case LinguaFranca.get_context(context)
      when 'character'
        return (Forgery::LoremIpsum.characters size, options).strip.capitalize if size.present?
        return Forgery::LoremIpsum.character, options
      when 'word'
        return (Forgery::LoremIpsum.words size, options).capitalize if size.present?
        return (Forgery::LoremIpsum.word options).capitalize
      when 'sentence'
        return Forgery::LoremIpsum.sentences size, options if size.present?
        return (Forgery::LoremIpsum.sentence options).capitalize
      when 'paragraph'
        return Forgery::LoremIpsum.sentences (size.present? ? size : I18n.config.default_paragraph_length), options
      when 'title'
        return (Forgery::LoremIpsum.words size, options).gsub(/\.$/, '').titlecase if size.present?
        return (Forgery::LoremIpsum.sentence options).gsub(/\.$/, '').titlecase
      end

      # if we didn't recognize it, it must be the default text so return it
      return context
    end

    def fallback(key, context = nil, context_size = nil)
      I18n.backend.needs_translation(key)
      # if a context was given, return some lorem ipsum
      return lorem_ipsum(context, context_size) if context

      # no context was given, make the key looks like words and return that
      key.to_s.gsub(/^.*\.(.+)?$/, '\1').gsub('_', ' ')
    end

    def call(exception, locale, key, options)
      str = nil
      if exception.is_a?(I18n::MissingTranslation)
        if options.has_key?(:resolve) && !options[:resolve]
          return nil
        end
        str = fallback(key, options[:context], options[:context_size])

        if I18n.backend.should_wrap?(str, options)
          str = I18n.backend.wrap(key, str, options)
        end
      else
        str = super
      end
      I18n.config.callback.i18n_exception(str, exception, locale, key) if I18n.config.callback.respond_to? :i18n_exception

      return str
    end
  end
end
