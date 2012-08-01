require 'king_placeholder/parser'
require 'active_support'
require 'active_support/version'

#  Define fields/methods of the including class as placeholders.
#  A Placeholder can be used inside any text string and will be replaced with a
#  stringified, formatted value(by KingViews gem => KingFormat::FormattingHelper.strfval )
#  Used for text snippets, PDF creation or E-Mail templates.
module KingPlaceholder
  extend ActiveSupport::Concern
  include ActiveSupport::Callbacks

  included do
    if ActiveSupport::VERSION::MAJOR == 3 && ActiveSupport::VERSION::MINOR > 0
      class_attribute :placeholders
    else
      class_inheritable_accessor :placeholders
    end
    placeholders = []
  end

  module ClassMethods
    # Define which fields(methods) are available to placeholder substitution.
    #
    # `before/after_expand_placeholders` hooks are run before the statemachine
    # parsing. Define those methods to setup env variables like I18n.locale or
    # whatever is required to format output strings.
    # The block is called in scope of the current object(self).
    # @example
    #   def before_expand_placeholders
    #     I18n.locale = self.language
    #     # self == current object
    #   end
    #   def after_expand_placeholders
    #     I18n.locale = nil
    #   end
    #
    # @param [Array[<Symbol>] fieldnames
    def has_placeholders(*fieldnames)
      self.placeholders = fieldnames
      define_callbacks :expand_placeholders
      set_callback :expand_placeholders, :before, :before_parsing
      set_callback :expand_placeholders, :after, :after_parsing
    end
  end

  # TODO inclusion deprecated in ActiveSupport 3.2.7, when gone move methods up into module
  module InstanceMethods

    # Check if a given field is declared as placeholder
    # @param [Object] fieldname to search in placeholders array
    # @return [Boolean]true if available
    def is_placeholder?(fieldname)
      self.class.placeholders.include?(fieldname.to_sym)
    end

    # Substitute placeholder in a string with their current values.
    # It handles strings, arrays (of strings) or hashes (with string values)
    # and returns data with the same data type e.g. if you put a hash, you will
    # get a hash.
    #
    # @examples
    #
    # Placeholders in text strings can be written in different notations.
    #
    # === Simple Notation:
    #
    #  => [first_name]
    # The fieldname is directly looked up on the current class:
    # client.expand_placeholders("Hello [first_name]")
    #   => "Hello Herbert"
    # invoice.expand_placeholders(["You owe me [price_to_pay]", "Invoice Nr. [number]"])
    #   => ["You owe me 495,00 EUR", "Invoice Nr. 123"]
    #
    # === Namespaced Notation
    #
    # => [company.organisation]
    # If the prefix equals the type of the current object the field is looked up on it.
    #   client.expand_placeholders("Hello [client.first_name]")
    #   => "Hello Herbert"
    #
    # If the prefix is a single related object => Client :belongs_to Company,
    # the substitution is delegated to that class.
    #   client.expand_placeholders("Belongs to [company.name]")
    #   => ""Belongs to Big Money Coorp."
    # It goes down all the way:
    #   invoice.expand_placeholders("[client.company.default_address.zip]")
    #   => "50999"
    #
    # === Namespaced Notation with multiple related objects
    #
    # In a has_many relationship, related objects reside in an array, which can
    # be reached using two different strategies.
    #
    # Access and Iterate over the whole Group:
    #   invoice.expand_placeholders("You bought: [items] [name] [/items]")
    #   => "You bought: Apple Banana Orange"
    #
    # Access a single object by its array index:
    #   invoice.expand_placeholders("You bought an [items.0.name] for [items.0.price]")
    #   => "You bought an Apple for 12 EUR"
    #
    # @param [Hash|Array|String] content with placeholders
    # @param [Object] opts - unused for now
    # @return [Hash|Array|String] whatever type you throw in is also returned
    def expand_placeholders(content, opts={})
      if content.is_a?(Array)
        result = []
        content.each{|element| result << self.expand_placeholders(element, opts) }
        return result
      elsif content.is_a?(Hash)
        result = {}
        content.each_pair{ |key,val| result[key] = self.expand_placeholders(val, opts) }
        return result
      else # Only proceed with strings
        return content unless content.is_a?(String)
      end
      run_callbacks :expand_placeholders do
        opts[:formatter] = :format_placeholder if self.respond_to?(:format_placeholder)
        parser = KingPlaceholder::Parser.new(self, content, opts)
        parser.sm.match
        parser.result if parser.sm.state == :finished
      end
    end

    protected
      def before_parsing
        before_expand_placeholders if self.respond_to?(:before_expand_placeholders)
      end
      def after_parsing
        after_expand_placeholders if self.respond_to?(:after_expand_placeholders)
      end
  end # instance methods
end # KingPlaceholders