require File.dirname(__FILE__) + '/../test_helper'
require 'fast_controller'

# Re-raise errors caught by the controller.
class FastController; def rescue_action(e) raise e end; end

class FastControllerTest < Test::Unit::TestCase
  def setup
    @controller = FastController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
