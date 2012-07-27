require 'spec_helper'

class BaseModel < ActiveRecord::Base
#  include KingFormat::FormattingHelper
  include KingPlaceholder
end
# Construct dummy models
class Master < BaseModel
  def self.columns; []; end
  attr_accessor :string_field
  has_many :details
  has_one :side
  has_placeholders :string_field
end

class Side < BaseModel
  def self.columns; []; end
  attr_accessor :field
  belongs_to :master
  has_placeholders :field
end

class Detail < BaseModel
  include KingFormat::MoneyFields               # has_money_fields
  def self.columns; []; end
  attr_accessor :int_field, :money_field, :secret_field, :currency
  belongs_to :master
  has_money_fields :money_field
  has_placeholders :int_field, :money_field
end

describe "Model with placeholders" do

  before :each do
    I18n.locale = :en_master
    # Thread problems with rspec .. fun
#    Thread.current[:default_currency_format] = I18n.t(:'number.currency.format')
    @record = Detail.new :int_field => 1000,
                         :money_field => 12.34
  end

  it "should have native values" do
    @record.int_field.should == 1000
    @record.money_field.should == 12.34
  end

  it "should have placeholder values" do
    @record.expand_placeholders("[int_field]").should == "1000"
    @record.expand_placeholders("[money_field]").should == "12.34 $"
  end

end

describe "Expanding of strings containing placeholder" do

  before :each do
    I18n.locale = :en_master
    @side = Side.new :field => 123
    @master = Master.new :string_field => 'foo', :side => @side
    @side.master = @master

    @detail1 = Detail.new :int_field => 1001,
                         :money_field => 12.34,
                         :secret_field => 'top-secret',
                         :master => @master
    @detail2 = Detail.new :int_field => 1002,
                        :money_field => 45.67,
                        :secret_field => 'little secret',
                        :master => @master
    @master.stub!(:details).and_return([@detail1, @detail2])
  end

  it 'should expand placeholders with no placeholders there' do
    @detail1.expand_placeholders('without placeholder').should == 'without placeholder'
    @detail1.expand_placeholders('[]').should == '[]'
    @detail1.expand_placeholders('').should == ''
    @detail1.expand_placeholders(nil).should == nil
    @detail1.expand_placeholders("\n").should == "\n"
  end

  it 'should expand placeholders with simple fieldname' do
    @detail1.expand_placeholders('[int_field]').should == '1001'
    @detail1.expand_placeholders("[int_field]\n").should == "1001\n"
    @detail1.expand_placeholders('[int_field]---[int_field]').should == '1001---1001'
    @detail1.expand_placeholders('[int_field]---[money_field]').should == '1001---12.34 $'
  end

  it 'should not expand placeholder for secret field' do
    @detail1.expand_placeholders('[secret_field]').should == 'UNKNOWN for Detail: secret_field'
  end

  it 'should expand placeholder with namespaced fieldname' do
    @detail1.expand_placeholders('[master.string_field]').should == 'foo'
    @detail1.expand_placeholders('[master.string_field] [int_field]').should == 'foo 1001'
  end

  it 'should expand placeholder with namespaced to self fieldname' do
    @detail1.expand_placeholders('[detail.int_field]').should == '1001'
    @detail1.expand_placeholders('[detail.master.string_field] [detail.int_field]').should == 'foo 1001'
  end

  it 'should expand with multiple steps' do
    @detail1.expand_placeholders('[master.side.field]').should == '123'
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

  it 'should expand placeholder group' do
    @master.expand_placeholders('[details][int_field]\n[/details]').should == '1001\n1002\n'
    @master.expand_placeholders('[details]Test:[int_field][/details]').should == 'Test:1001Test:1002'
    @master.expand_placeholders("[details][int_field]\n[/details]").should == "1001\n1002\n"

    @master.expand_placeholders('[details][foo][/details]').should == 'UNKNOWN for Detail: fooUNKNOWN for Detail: foo'
  end

  it 'should expand valid but empty placeholder group with empty string' do
    master = Master.new :string_field => 'a string'
    master.expand_placeholders('[details][int_field][/details]').should == ''
  end

  it 'should expand single item from a placeholder group' do
    @master.expand_placeholders('[details.0.int_field]').should == '1001'
    @master.expand_placeholders('[details.1.int_field]').should == '1002'
  end

  it 'should expand single item in empty placeholder group with empty string' do
    master = Master.new :string_field => 'a string'
    master.expand_placeholders('[details.0.int_field]').should == ''
  end

  it 'should expand empty single item from placeholder group with empty string' do
     @master.expand_placeholders('[details.10.int_field]').should == ''
  end

  it 'should expand placeholder group for non ending group' do
    @master.expand_placeholders("[details][int_field]").should == "END MISSING FOR detailsUNKNOWN for Master: int_field"
  end

  # TODO: Make this possible!
#   it "should expand placeholder group if referenced with namespace" do
#       @master.expand_placeholders("[master.details][int_field][end]").should == "10011002"
#   end

  it "should expand placeholders in an array" do
    @detail1.expand_placeholders(['[int_field]', '[money_field]', 'static']).should == ['1001', '12.34 $', 'static']
  end

  it "should expand placeholders in a hash" do
    @detail1.expand_placeholders( :key1 => '[int_field]',
                                  :key2 => '[money_field]',
                                  :key3 => 'static'
                                ).should ==
                                  { :key1 => '1001',
                                    :key2 => '12.34 $',
                                    :key3 => 'static' }
  end
end