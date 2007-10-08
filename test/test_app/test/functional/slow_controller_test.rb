require File.dirname(__FILE__) + '/../test_helper'
require 'slow_controller'

# Re-raise errors caught by the controller.
class SlowController; def rescue_action(e) raise e end; end

class SlowControllerTest < Test::Unit::TestCase
  def setup
    @controller = SlowController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
