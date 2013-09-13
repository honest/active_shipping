require "test_helper"

class LandmarkTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @items = TestFixtures.line_items1
    @beverly_hills = @locations[:beverly_hills]
    @ottawa = @locations[:ottawa]
    @chocolate = @packages[:chocolate_stuff]
    @carrier = Landmark.new(:username => 'demoapi', :password => 'demo123', :test => true)
  end

  def test_create_shipment
    mock_response = xml_fixture('landmark/create_shipment')
    @carrier.expects(:commit).returns(mock_response)
    resp = @carrier.create_shipment(@beverly_hills, @ottawa, @chocolate, @items)
    assert resp.success?
    assert resp.test?
    assert resp.is_a?(ShippingResponse)
    assert resp.shipping_id.present?
    assert resp.tracking_number.present?
    assert resp.label.present?
  end

  def test_create_shipment_error
    @nottawa = Location.new(@ottawa.to_hash.merge(:postal_code => 'ABCDE'))
    mock_response = xml_fixture('landmark/create_shipment_error')
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:commit).returns(mock_response)
      @carrier.create_shipment(@beverly_hills, @nottawa, @chocolate, @items)
    end
  end

  def test_find_tracking_info 
    mock_response = xml_fixture('landmark/tracking')
    @carrier.expects(:commit).returns(mock_response)
    info = @carrier.find_tracking_info('00000098760')
    assert info.success?
    assert info.test?
    assert info.is_a?(TrackingResponse)
  end

  def test_find_tracking_info_error
    mock_response = xml_fixture('landmark/tracking_error')
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:commit).returns(mock_response)
      @carrier.find_tracking_info('00000098760')
    end
  end

  def test_create_shipment_group_all
    @carrier.create_shipment(@beverly_hills, @ottawa, @chocolate, @items)
    info = @carrier.create_shipment_group(['xxx1'], region: 'Canada East')
    puts info.inspect
  end

  def test_build_tracking_request__default
    default_options = @carrier.instance_variable_get(:@options)
    xml = @carrier.send(:build_tracking_request, "tracking_number", default_options)
    request_as_hash = Hash.from_xml(xml)
    expected_hash = {
      "Login"=>{
        "Username"=>"demoapi", "Password"=>"demo123"
      },
      "TrackingNumber"=>"tracking_number",
      "Test"=>"true",
    }

    assert_equal(request_as_hash["TrackRequest"], expected_hash)
  end

  def test_build_tracking_request__adds_retreival_type_if_option_passed
    default_options = @carrier.instance_variable_get(:@options)
    xml = @carrier.send(:build_tracking_request, "tracking_number", default_options.merge(include_historical_events: true))
    request_as_hash = Hash.from_xml(xml)
    expected_hash = {
      "Login"=>{
        "Username"=>"demoapi", "Password"=>"demo123"
      },
      "TrackingNumber"=>"tracking_number",
      "RetrievalType"=>"Historical",
      "Test"=>"true",
    }

    assert_equal(request_as_hash["TrackRequest"], expected_hash)
  end
end