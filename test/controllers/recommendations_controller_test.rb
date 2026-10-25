require "test_helper"

class RecommendationsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get recommendations_path
    assert_redirected_to new_session_path
  end

  test "shows an active form without fetching candidates before submission" do
    sign_in_as users(:one)
    get recommendations_path
    assert_response :success
    assert_select "form[action='#{recommendations_path}']" do
      assert_select "button[disabled]", count: 0
    end
    assert_select "[data-controller*='pending-action']", count: 0
  end
end
