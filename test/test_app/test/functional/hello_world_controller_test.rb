require File.dirname(__FILE__) + '/../test_helper'
require 'hello_world_controller'

# Re-raise errors caught by the controller.
class HelloWorldController; def rescue_action(e) raise e end; end

class HelloWorldControllerTest < Test::Unit::TestCase
  def setup
    @controller = HelloWorldController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
