require 'spec_helper'

# Construct dummy classes
class Company
  include KingPlaceholder
  attr_accessor :name
  attr_accessor :clients    # has_many
  attr_accessor :user       # belongs_to
  has_placeholders :name
end

class User
  include KingPlaceholder
  attr_accessor :email
  attr_accessor :company
  has_placeholders :email
end

class Client
  include KingPlaceholder
  attr_accessor :number, :money_field, :secret_field, :currency
  attr_accessor :company
  has_placeholders :number, :money_field
end

describe 'Class with placeholders' do

  before :each do
    @client = Client.new
    @client.number = 1002
    @client.money_field = 12.333
  end

  it 'should have native values' do
    @client.number.should == 1002
    @client.money_field.should == 12.333
  end

  it 'should have placeholder value' do
    @client.expand_placeholders('[number]').should == '1002'
    @client.expand_placeholders('[money_field]').should == '12.333'
  end
  it 'should expand placeholders in an array' do
    @client.expand_placeholders(['[number]', '[money_field]', 'static']).should == ['1002', '12.333', 'static']
  end

  it 'should expand placeholders in a hash' do
    @client.expand_placeholders( :key1 => '[number]',
                                 :key2 => '[money_field]',
                                 :key3 => 'static'
                                ).should ==
                                 { :key1 => '1002',
                                   :key2 => '12.333',
                                   :key3 => 'static' }
  end
end

describe 'Placeholder substitution' do

  before :each do
    I18n.locale = :en
    @user = User.new
    @user.email = 'a@b.com'
    @company = Company.new
    @company.name = 'BigMoney Inc.'
    @company.user = @user
    @user.company = @company

    @client = Client.new
    @client.number = 1001
    @client.money_field = 12.34
    @client.secret_field = 'top-secret'
    @client.company = @company

    @client_1 = Client.new
    @client_1.number = 1002
    @client_1.money_field = 45.67
    @client_1.secret_field = 'little secret'
    @client_1.company = @company
    @company.clients = [@client, @client_1]
  end

  context 'with direct lookup' do

    it 'should return without placeholders' do
      @client.expand_placeholders('without placeholder').should == 'without placeholder'
      @client.expand_placeholders('[]').should == '[]'
      @client.expand_placeholders('').should == ''
      @client.expand_placeholders(nil).should == nil
      @client.expand_placeholders("\n").should == "\n"
    end

    it 'should expand with simple fieldname' do
      @client.expand_placeholders('[number]').should == '1001'
      @client.expand_placeholders("[number]\n").should == "1001\n"
      @client.expand_placeholders('[number]---[number]--[money_field]').should == '1001---1001--12.34'
    end

    it 'should not parse unknown field' do
      @client.expand_placeholders('[secret_field]').should == 'UNKNOWN for Client: secret_field'
    end

    it 'should expand placeholder with not existing namespaces' do
      @client.expand_placeholders('[nothing.name]').should == 'UNKNOWN for Client: nothing.name'
    end

    it 'should expand placeholder with wrong namespaces' do
      @client.expand_placeholders('[company.this.are.too.much.namespaces]').should == 'UNKNOWN for Company: this.are.too.much.namespaces'
      @client.expand_placeholders('[this.are.too.much.namespaces]').should == 'UNKNOWN for Client: this.are.too.much.namespaces'
      @client.expand_placeholders('[...]').should == 'UNKNOWN for Client: ...'
      @client.expand_placeholders('[unknown]').should == 'UNKNOWN for Client: unknown'
    end
  end

  context 'with namespace' do

    it 'should parse referenced object fields' do
      @client.expand_placeholders('[company.name]').should == 'BigMoney Inc.'
      @client.expand_placeholders('[company.name] [number]').should == 'BigMoney Inc. 1001'
    end

    it 'should parse self referenced field' do
      @client.expand_placeholders('[client.number]').should == '1001'
      @client.expand_placeholders('[client.company.name] [client.number]').should == 'BigMoney Inc. 1001'
    end

    it 'should parse multiple steps' do
      @client.expand_placeholders('[company.user.email]').should == 'a@b.com'
    end

  end

  context 'with empty fields' do

    it 'should parse valid but empty placeholder group with empty string' do
      company = Company.new
      company.clients = []
      company.expand_placeholders('[clients][number][/clients]').should == ''
    end

    it 'should parse single item group with empty string' do
      @company.expand_placeholders('[clients.10.number]').should == ''
    end

    it 'should parse related object email with empty string' do
      @company.name = nil
      @client.expand_placeholders('[company.name]').should == ''
    end

    it 'should parse empty related object with empty string' do
      @client.company = nil
      @client.expand_placeholders('[company.name]').should == ''
      @client.expand_placeholders('[client.company.name]').should == ''
    end

  end

  context 'with collection' do
    it 'should expand' do
      @company.expand_placeholders('[clients][number]\n[/clients]').should == '1001\n1002\n'
      @company.expand_placeholders('[clients]Test:[number][/clients]').should == 'Test:1001Test:1002'
      @company.expand_placeholders("[clients][number]\n[/clients]").should == "1001\n1002\n"
      @company.expand_placeholders('[clients][foo][/clients]').should == 'UNKNOWN for Client: fooUNKNOWN for Client: foo'
    end

    it 'should expand single item ' do
      @company.expand_placeholders('[clients.1.number]').should == '1001'
      @company.expand_placeholders('[clients.2.number]').should == '1002'
    end

    it 'should show error for missing closing' do
      @company.expand_placeholders('[clients][number]').should == 'END MISSING FOR clientsUNKNOWN for Company: number'
    end
  end

  context 'with custom formatter' do
    before :each do
      I18n.locale = :en_company
    #    Thread.current[:default_currency_format] = I18n.t(:'number.currency.format')
    end

    xit 'should format money' do
      @client.expand_placeholders('[money_field]').should == '$12.34'
    end
  end


end