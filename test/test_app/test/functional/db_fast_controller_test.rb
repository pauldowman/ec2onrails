require File.dirname(__FILE__) + '/../test_helper'
require 'db_fast_controller'

# Re-raise errors caught by the controller.
class DbFastController; def rescue_action(e) raise e end; end

class DbFastControllerTest < Test::Unit::TestCase
  def setup
    @controller = DbFastController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
