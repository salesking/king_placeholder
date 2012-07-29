require 'statemachine'
require 'active_support/core_ext/string/inflections'
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
  class Parser
    # reference to statemachine
    attr_accessor :sm
    # incoming string
    attr_accessor :content
    # Output string, with placeholders substituted
    attr_accessor :result
    # the current object
    attr_accessor :obj
    # parse-options hash
    attr_accessor :opts

    # @param [Object] obj object responding to has_placeholder
    # @param [String] content containing placeholders
    # @param [Hash{Symbol=>Mixed}] opts parser options (none so far)
    def initialize(obj, content, opts={})
      @sm = ParseMachine.create_with(self) # init statemachine
      @obj = obj
      @content = content
      @opts = opts
    end

    # Before matching is done deep copy content, because otherwise result.gsub!
    # breaks recursion
    def prepare
      @result = @content.dup
    end

    # Match all placeholder(inside the brackets []) and replace them with their
    # values
    # See #expand_placeholders for docs
    # When finished matching, triggers finished_matching event on statemachine
    def parse
      while match = @result.match(/\[((\w|\.)+)\]/)
        @placeholder = match[0] #  with brackets - current placeholder
        @field = match[1]       # without brackets - current field

        check_current_prefix

        if @field['.']
          sub_object
        elsif obj.respond_to?(@field) && ( @cur_collection = obj.send(@field) ).is_a?(Array)
          sub_collection
        else
          sub_string
        end
        # If placeholder still exists here, it can't be recognized, sub with error
        @result.gsub!(@placeholder, "UNKNOWN for #{obj.class.to_s}: #{@field}")
      end
      @sm.finished_matching
    end

    def cleanup

    end

    private

    # Final destination of each placeholder in it's simple notation without
    # namespace e.g. [price_to_pay]
    def sub_string
      return unless obj.is_placeholder?(@field)
      value = if @opts[:formatter]
                obj.send(@opts[:formatter], @field)
              else
                obj.send @field
              end
      #value = strfval(obj, @field)
      @result.gsub!(@placeholder, value.to_s) if value
    end

    # Namespaced notation, for related objects. E.g an invoice belonging to a
    # company:
    #   [company.default_address.zip]
    # instead of
    #   [invoice.company.default_address.zip]
    def sub_object
      splits= @field.split('.')
      object_name = splits.first
      field_names = splits[1..-1] # all but the first
      return unless object_name && obj.respond_to?(object_name)
      object = obj.send(object_name)
      # Its a collection => invoice.items and access is done by ary index:
      # first item => [items.1.name]
      if object.is_a?(Array) && ary_index = field_names.first[/\A\d*\z/]
        field_names.delete_at(0) # remove entry from field_names ary
        # replace with empty string if the index does not exist or obj is empty
        @result.gsub!(@placeholder, '') unless object = object[ary_index.to_i-1]
      end

      # Recurse and let the referenced object do the expanding
      if object.respond_to?(:expand_placeholders)
        value = object.expand_placeholders("[#{field_names.join('.')}]")
        @result.gsub!(@placeholder, value)
      end
    end

    # The current field is the beginning of a group, which needs to be ended by
    # [/field_name]
    # e.g. [items] Item price: [price] \n [/items]
    def sub_collection
      if match = @result.match(/\[#{@field}\](.*)\[\/#{@field}\]/m) # the /m makes the dot match newlines, too!
        whole_group = match[0]
        inner_placeholders = match[1]
        inner_result = ''
         # Let the referenced object do the expanding by recursion if the collection knows placeholders
        @cur_collection.each do |item|
          inner_result << item.expand_placeholders(inner_placeholders)
        end if @cur_collection.first.respond_to?(:expand_placeholders)
        @result.gsub!(whole_group, inner_result)
      else
        @result.gsub!(@placeholder, "END MISSING FOR #{@field}")
      end
    end

    # Checks if the field name contains the current object's class name.
    # Kick the prefix if the current class matches it, e.g:
    #   Inside a client object
    #   client.number => number
    def check_current_prefix
      if @field['.']
        splits = @field.split('.')
        object_name = splits.first
        if object_name && obj.class.name == object_name.classify
          splits.delete_at(0) # kick the object portion => invoice
          @field = splits.join('.') # glue the rest back together [number]
        end
      end
    end

  end #class
end #module