
module LinguaFrancaFormHelper
  include ActionView::Helpers::FormTagHelper

  class FormBuilder < ActionView::Helpers::FormBuilder
    def submit_default_value
      @do_wrap = true
      I18n.t(i18n_key, :scope => i18n_scope)
    end

    def submit(value = nil, options = {})
      if value.present? && value.is_a?(Symbol)
        @action = value
        value = nil
      end
      i18n_wrap(super(value, options))
    end

    def button(value = nil, options = {}, &block)
      if value.present? && value.is_a?(Symbol)
        @action = value
        options[:name] ||= @action
        value = nil
      end
      value = submit_default_value if value.nil?
      super(i18n_wrap(value), options, &block)
    end

    private
      def i18n_wrap(html)
        @do_wrap ||= false
        if @do_wrap
          html = I18n.backend.wrap(html, i18n_key, :scope => i18n_scope)
        end
        html
      end

      def i18n_key
        @action ||= nil
        object = convert_to_model(@object)
        action = @action || (object ? (object.persisted? ? :update : :create) : :submit)
        model = object.respond_to?(:model_name) ? object.model_name.i18n_key : @object_name.to_s.camelize
        "#{model}.#{action}"
      end

      def i18n_scope
        "forms.actions"
      end
  end
end

module LinguaFranca
  module FormHelpers
    module Placeholderable
      def initialize(object_name, method_name, template_object, options = {})
        if options[:placeholder] === true
          options[:placeholder] = I18n.t("#{object_name}.#{method_name}", :scope => "forms.placeholders")
          @do_wrap = true
        end
        super(object_name, method_name, template_object, options)
      end

      def tag(*)
        if (@do_wrap ||= false)
          I18n.backend.wrap(super, "#{@object_name}.#{@method_name}", :scope => "forms.placeholders")
        else
          super
        end
      end
    end
  end
end

module ActionView
  module Helpers
    module Tags
      class Label
        class LabelBuilder
          def translation
            name = object.respond_to?(:to_model) ? object.model_name.i18n_key : @object_name
            I18n.backend.wrap(nil, "#{name}.#{@method_name}", :scope => "forms.labels")
          end
        end
      end
    end

    module FormOptionsHelper
      def this_options_for_select(container, selected)
        # if it's in the form [a, b, c] and not [[a,1], [b,2], [c,3]]
        if container.is_a?(Array) && !container.first.is_a?(Array)
          # save it as a hash for now, then we'll be able to compile it later and 
          return {:lingua_franca_options => true, :options => container, :selected => selected }
        end
        super_options_for_select(container, selected)
      end
      alias_method :super_options_for_select, :options_for_select
      alias_method :options_for_select, :this_options_for_select
    end

    module FormTagHelper
      def this_select_tag(name, option_tags = nil, options = {})
        if option_tags.present? && option_tags.is_a?(Hash)
          info = option_tags
          keys = Array.new
          option_tags = 
            options_for_select(
              info[:options].collect do |k|
                key = options[:scope] ? "#{options[:scope]}.#{k}" : "forms.options.#{name}.#{k}"
                keys << key
                [I18n.t(key), k]
              end,
              info[:selected]
            )
          return I18n.backend.wrap(super_select_tag(name, option_tags, options), keys)
        end
        super_select_tag(name, option_tags, options)
      end

      def this_submit_tag(value = nil, options = {})
        if value.nil? || value.is_a?(Symbol)
          key = "forms.actions.generic.#{(value || :submit).to_s}"
          return I18n.backend.wrap(super_submit_tag(I18n.t(key), options), key)
        end
        super_submit_tag(value, options)
      end

      def this_button_tag(value = nil, options = {}, &block)
        if !block_given? && (value.nil? || value.is_a?(Symbol))
          key = "forms.actions.generic.#{(value || :button).to_s}"
          return I18n.backend.wrap(super_button_tag(I18n.t(key), options), key)
        end
        super_button_tag(value, options, &block)
      end

      def placeholderable(super_method, name, value = nil, options = {})
        if options[:placeholder] === true
          options[:placeholder] = I18n.t("generic.#{name}", :scope => "forms.placeholders")
          return I18n.backend.wrap(send(super_method, name, value, options), "generic.#{name}", :scope => "forms.placeholders")
        end
        send(super_method, name, value, options)
      end

      def this_label_tag(name = nil, content_or_options = nil, options = nil, &block)
        key_fragment = name
        
        if name.is_a?(Array)
          key_fragment = name.first
          name = name.last
        end

        if !block_given? &&
            (!content_or_options || content_or_options === true || content_or_options.is_a?(Symbol))
          key = "forms.labels.#{content_or_options.is_a?(Symbol) ? content_or_options : 'generic'}.#{key_fragment}"

          # if content_or_options === true then we'll push the key to the stack
          #  the user will be responsible for popping it using _!
          if content_or_options === true
            I18n.backend.push(key)
            content_or_options = nil
          else
            content_or_options = I18n.backend.wrap(I18n.t(key), key)
          end
        end
        super_label_tag(name, content_or_options, options, &block)
      end

      #def text_area_tag(name, content = nil, options = {})
      # if options.has_key?(:placeholder) && options[:placeholder] === true
      # end
      #end

      alias_method :super_label_tag, :label_tag
      alias_method :label_tag, :this_label_tag

      alias_method :super_select_tag, :select_tag
      alias_method :select_tag, :this_select_tag

      alias_method :super_submit_tag, :submit_tag
      alias_method :submit_tag, :this_submit_tag

      alias_method :super_button_tag, :button_tag
      alias_method :button_tag, :this_button_tag

      [:text_field, :password_field, :telephone_field, :search_field, :email_field, :url_field, :text_area].each { |type|
      class_eval <<-RUBY, __FILE__, __LINE__+1

      def this_#{type}_tag(name, value = nil, options = {})
        placeholderable(:super_#{type}_tag, name, value, options)
      end

      alias_method :super_#{type}_tag, :#{type}_tag
      alias_method :#{type}_tag, :this_#{type}_tag

        RUBY
      }
    end
  end
end

ActionView::Helpers::Tags::TextField.send :include, LinguaFranca::FormHelpers::Placeholderable
ActionView::Helpers::Tags::TextArea.send :include, LinguaFranca::FormHelpers::Placeholderable
ActionView::Base.default_form_builder = LinguaFrancaFormHelper::FormBuilder
