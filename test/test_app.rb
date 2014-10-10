require 'helper'
require 'json'

class InvalidAccountError < StandardError; end
class UnknownUserError    < StandardError; end

class NameApp
  include Newark

  rescue_from InvalidAccountError do |exception|
    [500, {'Content-Type' => 'plain/text'}, exception.message]
  end

  rescue_from UnknownUserError, :respond_to_invalid_user_error

  before do
    if params[:key] && params[:key] != '23'
      response.status = 403
      false
    end
  end

  def upcase(str)
    str.upcase
  end

  get '/upcaser' do
    upcase(params[:name])
  end

  get '/hello1' do
    hello
  end

  get '/fail' do
    'This should not be reached'
  end

  get '/hello2', :hello

  get '/error/:id' do
    if params[:id] == '123'
      raise InvalidAccountError, "errors occurred for #{params[:id]}"
    elsif params[:id] == 'unknown_user'
      raise UnknownUserError, "invalid user id for #{params[:id]}"
    end
  end

  private

  def hello
    'Hello'
  end

  def respond_to_invalid_user_error(exception)
    [404, {'Content-Type' => 'application/json'}, [{msg: exception.message}.to_json]]
  end

end

class TestApp < MiniTest::Unit::TestCase

  include Rack::Test::Methods

  def app
    NameApp.new
  end

  def test_instance_method_access
    get '/upcaser', { name: 'mike' }
    assert last_response.ok?
    assert_equal 'MIKE', last_response.body
  end

  def test_alternate_action_invocation
    get '/hello1'
    assert last_response.ok?
    assert_equal 'Hello', last_response.body

    get '/hello2'
    assert last_response.ok?
    assert_equal 'Hello', last_response.body
  end

  def test_before_hooks_halting_execution
    get '/fail', { key: '1234' }
    refute last_response.ok?
    assert_equal 403, last_response.status
    assert_equal '', last_response.body
  end

  def test_rescue_from_block
    get '/error/123'
    refute last_response.ok?
    assert_equal 500, last_response.status
    assert_equal 'errors occurred for 123', last_response.body
  end

  def test_rescue_from_method
    get '/error/unknown_user'
    refute last_response.ok?
    assert_equal 404, last_response.status
    assert_equal '{"msg":"invalid user id for unknown_user"}', last_response.body
  end

end
