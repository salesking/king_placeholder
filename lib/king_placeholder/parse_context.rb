require 'statemachine'
require 'action_view'       # king_views related suxs
require 'action_controller' # king_views
require 'king_views'
module KingPlaceholder
  # Statemachine for placeholder substitution
  # The statemachine is created and its state updated from within the Context
  # object. This only holds the state definitions.
  module ParseMachine

    def self.create_with(machine_context)
      return Statemachine.build do
        # Origin State  Event   Destination State   Action
        #     FROM      EVENT   TO          ACTION
        trans :waiting, :match, :matching, :prepare
        state :matching do
          on_entry :parse
        end
        trans :matching, :finished_matching, :finished, :cleanup
        context machine_context
      end
    end

  end

  # Statemachine context for placeholder substitution
  #
  # === Example
  #   machine = ParserContext.new(obj, content)
  #   # send match event
  #   machine.sm.match
  #   machine.result
  class ParseContext
    include ::KingFormat::FormattingHelper
    # reference to statemachine
    attr_accessor :sm
    # incoming string
    attr_accessor :content
    # Output string, with placeholders substituted
    attr_accessor :result
    # the current object
    attr_accessor :obj
    # hash parse options
    attr_accessor :opts

    # === Parameter
    # obj<Object>:: any object responding to has_placeholder
    # content<String>:: String containing placeholders
    # opts<Hash{Symbol=>Mixed}>:: parse options
    # :only<Array> => parse only the given placeholders
    def initialize(obj, content, opts={})
      @sm = ParseMachine.create_with(self) # init statemachine
      @obj = obj
      @content = content
      @opts = opts
    end

    # Before matching is done this method set's up environment variables like
    # current_language => i18n.locale
    # TODO: decouple and outsource into before_method block to set env vars from outside
    def prepare
      init_locale  #I18n.locale
      set_format_opts # merge date/money format into thread var
      # deep copy content, because otherwise result.gsub! breaks recursion
      @result = @content.dup
    end

    # Match all placeholder(inside the brackets []) and replace them with their
    # values
    # See #expand_placeholders for docs
    # When finished matching, triggers finished_matching event on statemachine
    def parse
      while match = @result.match(/\[((\w|\.)+)\]/)
        @c_placeholder = match[0] #  with brackets - current placeholder
        @c_field = match[1]       # without brackets - current field

        check_current_prefix

        if @c_field['.']
          sub_object
        elsif obj.respond_to?(@c_field) && ( @cur_collection = obj.send(@c_field) ).is_a?(Array)
          sub_collection
        else
          sub_string
        end
        # If placeholder still exists here, it can't be recognized, sub with error
        @result.gsub!(@c_placeholder, "UNKNOWN for #{obj.class.to_s}: #{@c_field}")
      end
      @sm.finished_matching
    end

    # When finished this method is called to cleanup f.ex. environment variables
    # like I18n.locale
    def cleanup
      @current_language && @current_language.reset_locale
    end

    private

    # Final destination of each placeholder in it's simple notation without
    # namespace e.g. [price_to_pay]
    def sub_string
      return unless obj.is_placeholder?(@c_field)
      # only parse some placeholders
#      return if opts[:only] && !opts[:only].include?(@c_field)
      value = strfval(obj, @c_field)
      @result.gsub!(@c_placeholder, value.to_s) if value
    end

    # Namespaced notation, for related objects. We are in invoice which belongs
    # to a company:
    #   [company.default_address.zip]
    # instead of
    #   [invoice.company.default_address.zip]
    def sub_object
      splitted = @c_field.split('.')
      object_name = splitted.first # just the first
      field_names = splitted[1..-1] # all but the first
      return unless object_name && obj.respond_to?(object_name) # the field exists
      object = obj.send(object_name)
      #check if its a collection => invoice.items and access is done by ary index items.0.name
      if object.is_a?(Array) && ary_index = field_names.first[/\A\d*\z/] # [items.5.name] match digit only string
        field_names.delete_at(0) # remove entry from field_names ary
        # replace with empty string if the index does not exist or obj is empty
        @result.gsub!(@c_placeholder, '') unless object = object[ary_index.to_i-1]
      end

      # Recurse and Let the referenced object do the expanding
      if object.respond_to?(:expand_placeholders)
        value = object.expand_placeholders("[#{field_names.join('.')}]")
        @result.gsub!(@c_placeholder, value)
      end
    end

    # The current field is the beginning of a group, which needs to be ended by
    # [/field_name]
    # e.g. [items] Item price: [price] \n [/items]
    def sub_collection
      if match = @result.match(/\[#{@c_field}\](.*)\[\/#{@c_field}\]/m) # the /m makes the dot match newlines, too!
        whole_group = match[0]
        inner_placeholders = match[1]
        inner_result = ''
         # Let the referenced object do the expanding by recursion if the collection knowns placeholders
        @cur_collection.each do |item|
          inner_result << item.expand_placeholders(inner_placeholders)
        end if @cur_collection.first.respond_to?(:expand_placeholders)
        @result.gsub!(whole_group, inner_result)
      else
        @result.gsub!(@c_placeholder, "END MISSING FOR #{@c_field}")
      end
    end

    # Checks if the current field name contains the current object's class name.
    # If the current class is an invoice, kick the prefix:
    #   invoice.number => number
    def check_current_prefix
      if @c_field['.']
        splitted = @c_field.split('.')
        object_name = splitted.first
        if object_name && obj.class.name == object_name.classify
          splitted.delete_at(0) # kick the object portion => invoice
          @c_field = splitted.join('.') # glue the rest back together [number]
        end
      end
    end

    # set format options for KingFormat date/money helpers
    # => strfval + strfmoney
    # very important, without those all formatting in views screws up
    def set_format_opts
      Thread.current[:default_currency_format] = if defined?(::Company) && ::Company.current
        ::Company.current.money_format
      elsif obj.respond_to?(:company) && obj.company
        obj.company.money_format
      elsif defined?(::Company) && obj.is_a?(::Company)
        obj.money_format
      else
        nil
      end

      Thread.current[:default_date_format] = if defined?(::Company) && ::Company.current
        ::Company.current.date_format
      elsif obj.respond_to?(:company) && obj.company
        obj.company.date_format
      elsif defined?(::Company) && obj.is_a?(::Company)
        obj.date_format
      else
        nil
      end
    end

    # Set i18n.locale to given or present custom company locale
    # locale is memoized in instance @current_language.
    # Only set if a company and the language is available
    # === Parameter
    # locale<String>:: locale code en, de,..
    def init_locale(locale=nil)
      if (locale || (obj.respond_to?(:language) && obj.language)) \
         && obj.respond_to?(:company) && obj.company
        @current_language ||= begin
          # find lang in scope of company
          ::Language.init_locale(obj.company, locale || obj.language)
        end
      end
    end
  end #class
end #module