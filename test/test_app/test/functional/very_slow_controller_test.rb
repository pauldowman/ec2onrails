require File.dirname(__FILE__) + '/../test_helper'
require 'very_slow_controller'

# Re-raise errors caught by the controller.
class VerySlowController; def rescue_action(e) raise e end; end

class VerySlowControllerTest < Test::Unit::TestCase
  def setup
    @controller = VerySlowController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
