require 'king_placeholder/parse_context'
require 'active_support'
require 'active_support/version'

#  Define fields/methods of the including class as placeholders.
#  A Placeholder can be used inside any text string and will be replaced with a
#  stringified, formatted value(by KingViews gem => KingFormat::FormattingHelper.strfval )
#  Used for text snippets, PDF creation or E-Mail templates.

module KingPlaceholder

  # sets :placeholders and init Class.placeholders as emtpy array on inclusion
  def self.included(base)
    if ActiveSupport::VERSION::MAJOR == 3 && ActiveSupport::VERSION::MINOR > 0
      base.class_attribute :placeholders
    else
      base.send :class_inheritable_accessor, :placeholders
    end
    base.placeholders = []
    base.extend(ClassMethods)
  end

  module ClassMethods

    #  Defines the fields returned by self.placeholders.
    #  Sets self.publish if empty.
    # ==== Parameter
    #  fieldnames<Array[Symbol]>:: the names of the fields which are available
    #  throught the placeholder methods
    def has_placeholders(*fieldnames)
      self.placeholders = fieldnames
      include InstanceMethods
    end
  end #ClassMethods

  module InstanceMethods

    # Check if a given field is declared as placeholder
    # TODO check usage and/or move to class methods
    # ==== Parameter
    # fieldname<String|Symbol>:: the field to search in the placeholders array
    # ==== Returns
    # <Boolean>:: true if in
    def is_placeholder?(fieldname)
      self.class.placeholders.include?(fieldname.to_sym)
    end

    # Substitute placeholder in a string with their current values.
    # It handles strings, arrays (of strings) or hashes (with string values)
    # and returns data with the same data type e.g. if you put a hash, you will
    # get a hash.
    #
    # ==== Examples
    #
    # Placeholders in text strings can be written in different notations.
    #
    # ===== Simple Notation:
    #
    #  => [first_name]
    # The fieldname is directly looked up on the current class:
    # client.expand_placeholders("Hello [first_name]")
    #   => "Hello Herbert"
    # invoice.expand_placeholders(["You owe me [price_to_pay]", "Invoice Nr. [number]"])
    #   => ["You owe me 495,00 EUR", "Invoice Nr. 123"]
    #
    # ===== Namespaced Notation
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
    # ===== Namespaced Notation with multiple related objects
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
    # === Parameter
    # content<Hash,Array, String>:: Collection, Hash or single string containing
    # placeholders
    # === Returns
    # <Hash,Array, String>:: whatever type you threw in is also returned
    def expand_placeholders(content, opts={})
      if content.is_a?(Array) # Expand all array elements and go recursive
        result = []
        content.each{|element| result << self.expand_placeholders(element, opts) }
        return result
      elsif content.is_a?(Hash) # Expand all hash elements and go recursive
        result = {}
        content.each_pair{ |key,val| result[key] = self.expand_placeholders(val, opts) }
        return result
      else # Only proceed with strings
        return content unless content.is_a?(String)
      end
      parser = KingPlaceholder::ParseContext.new(self, content, opts)
      parser.sm.match
      parser.result if parser.sm.state == :finished
    end
  end # instance methods
end # KingPlaceholders