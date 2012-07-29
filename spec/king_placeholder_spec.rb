require 'spec_helper'

# Construct dummy classes
class Master
  include KingPlaceholder
  attr_accessor :string_field
  attr_accessor :details
  attr_accessor :side
  has_placeholders :string_field
end

class Side
  include KingPlaceholder
  attr_accessor :field
  attr_accessor :master
  has_placeholders :field
end

class Detail
  include KingPlaceholder
  include KingFormat::MoneyFields
  attr_accessor :int_field, :money_field, :secret_field, :currency
  attr_accessor :master
  has_money_fields :money_field
  has_placeholders :int_field, :money_field
end

describe 'Class with placeholders' do

  before :each do
    I18n.locale = :en_master
#    Thread.current[:default_currency_format] = I18n.t(:'number.currency.format')
    @record = Detail.new
    @record.int_field = 1000
    @record.money_field = 12.34
  end

  it 'should have native values' do
    @record.int_field.should == 1000
    @record.money_field.should == 12.34
  end

  it 'should have placeholder values' do
    @record.expand_placeholders('[int_field]').should == '1000'
    @record.expand_placeholders('[money_field]').should == '$12.34'
  end

end

describe 'Placeholder substitution' do

  before :each do
    I18n.locale = :en
    @side = Side.new
    @side.field = 123
    @master = Master.new
    @master.string_field = 'foo'
    @master.side = @side
    @side.master = @master

    @detail1 = Detail.new
    @detail1.int_field = 1001
    @detail1.money_field = 12.34
    @detail1.secret_field = 'top-secret'
    @detail1.master = @master

    @detail2 = Detail.new
    @detail2.int_field = 1002
    @detail2.money_field = 45.67
    @detail2.secret_field = 'little secret'
    @detail2.master = @master
    @master.details = [@detail1, @detail2]
  end

  context 'with direct lookup' do

    it 'should return without placeholders' do
      @detail1.expand_placeholders('without placeholder').should == 'without placeholder'
      @detail1.expand_placeholders('[]').should == '[]'
      @detail1.expand_placeholders('').should == ''
      @detail1.expand_placeholders(nil).should == nil
      @detail1.expand_placeholders("\n").should == "\n"
    end

    it 'should expand with simple fieldname' do
      @detail1.expand_placeholders('[int_field]').should == '1001'
      @detail1.expand_placeholders("[int_field]\n").should == "1001\n"
      @detail1.expand_placeholders('[int_field]---[int_field]').should == '1001---1001'
      @detail1.expand_placeholders('[int_field]---[money_field]').should == '1001---$12.34'
    end

    it 'should not parse unknown field' do
      @detail1.expand_placeholders('[secret_field]').should == 'UNKNOWN for Detail: secret_field'
    end

    it 'should expand placeholder with not existing namespaces' do
      @detail1.expand_placeholders('[nothing.string_field]').should == 'UNKNOWN for Detail: nothing.string_field'
    end

    it 'should expand placeholder with wrong namespaces' do
      @detail1.expand_placeholders('[master.this.are.too.much.namespaces]').should == 'UNKNOWN for Master: this.are.too.much.namespaces'
      @detail1.expand_placeholders('[this.are.too.much.namespaces]').should == 'UNKNOWN for Detail: this.are.too.much.namespaces'
      @detail1.expand_placeholders('[...]').should == 'UNKNOWN for Detail: ...'
      @detail1.expand_placeholders('[unknown]').should == 'UNKNOWN for Detail: unknown'
    end
  end

  context 'with namespace' do

    it 'should parse referenced object fields' do
      @detail1.expand_placeholders('[master.string_field]').should == 'foo'
      @detail1.expand_placeholders('[master.string_field] [int_field]').should == 'foo 1001'
    end

    it 'should parse self referenced field' do
      @detail1.expand_placeholders('[detail.int_field]').should == '1001'
      @detail1.expand_placeholders('[detail.master.string_field] [detail.int_field]').should == 'foo 1001'
    end

    it 'should parse with multiple steps' do
      @detail1.expand_placeholders('[master.side.field]').should == '123'
    end
  end

  context 'with empty fields' do
    it 'should expand valid but empty placeholder group with empty string' do
      master = Master.new
      master.details = []
      master.expand_placeholders('[details][int_field][/details]').should == ''
    end
    it 'should expand single item group with empty string' do
      @master.expand_placeholders('[details.10.int_field]').should == ''
    end
  end

  context 'with groups' do
    it 'should expand' do
      @master.expand_placeholders('[details][int_field]\n[/details]').should == '1001\n1002\n'
      @master.expand_placeholders('[details]Test:[int_field][/details]').should == 'Test:1001Test:1002'
      @master.expand_placeholders("[details][int_field]\n[/details]").should == "1001\n1002\n"
      @master.expand_placeholders('[details][foo][/details]').should == 'UNKNOWN for Detail: fooUNKNOWN for Detail: foo'
    end

    it 'should expand single item ' do
      @master.expand_placeholders('[details.1.int_field]').should == '1001'
      @master.expand_placeholders('[details.2.int_field]').should == '1002'
    end

    it 'should show error for missing closing' do
      @master.expand_placeholders('[details][int_field]').should == 'END MISSING FOR detailsUNKNOWN for Master: int_field'
    end
  end


  it 'should expand placeholders in an array' do
    @detail1.expand_placeholders(['[int_field]', '[money_field]', 'static']).should == ['1001', '$12.34', 'static']
  end

  it 'should expand placeholders in a hash' do
    @detail1.expand_placeholders( :key1 => '[int_field]',
                                  :key2 => '[money_field]',
                                  :key3 => 'static'
                                ).should ==
                                  { :key1 => '1001',
                                    :key2 => '$12.34',
                                    :key3 => 'static' }
  end
end