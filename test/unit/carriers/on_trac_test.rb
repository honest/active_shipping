require "test_helper"

class OnTracTest < Test::Unit::TestCase
  def setup
    @carrier = OnTrac.new(:account => 37, :password => 'testpass', :test => true)
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @beverly_hills = @locations[:beverly_hills]
    @old_honest = Location.new({
      :address1 => "1550 17th Street",
      :city => "Santa Monica",
      :state => "CA",
      :postal_code => "90404",
      :country => 'US'
    })
    @chocolate = @packages[:chocolate_stuff]
  end

  def test_invalid_rate_credentials
    mock_response = xml_fixture('on_trac/invalid_credentials')
    @carrier = OnTrac.new(:account => 37, :password => 'badpass', :test => true)
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:ssl_get).returns(mock_response)
      @carrier.find_rates(@beverly_hills, @old_honest, [@chocolate])
    end
  end

  def test_find_rates
    mock_response = xml_fixture('on_trac/rates')
    @carrier.expects(:ssl_get).returns(mock_response)
    resp = @carrier.find_rates(@beverly_hills, @old_honest, [@chocolate])
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully Retrieved rate"
    assert_equal resp.params['ServiceChrg'], "6.55"
    assert_equal resp.params['FuelCharge'], "0.49"
    assert_equal resp.params['TotalCharge'], "7.04"
  end

  def test_find_rates_error
    mock_response = xml_fixture('on_trac/rates_error')
    @dishonest = Location.new(@old_honest.to_hash.merge(:postal_code => 'ABCDE'))
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:ssl_get).returns(mock_response)
      @carrier.find_rates(@beverly_hills, @dishonest, [@chocolate])
    end
  end

  def test_zips_success
    mock_response = xml_fixture('on_trac/zips')
    @carrier.expects(:ssl_get).returns(mock_response)
    zips = @carrier.zips
    assert zips.success?
    assert zips.test
    assert_equal zips.message, "Successfully Retrieved zips"
    assert /\d{5}/.match(zips.params.first[0])
  end

  def test_zips_error
    mock_response = xml_fixture('on_trac/zips_error')
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:ssl_get).returns(mock_response)
      @carrier.zips(Time.now)
    end
  end

  def test_create_shipment
    mock_response = xml_fixture('on_trac/shipment')
    @carrier.expects(:ssl_post).returns(mock_response)
    resp = @carrier.create_shipment(@beverly_hills, @old_honest, @chocolate)
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully created shipment"
    assert_equal resp.params['ServiceChrg'], "6.55"
    assert_equal resp.params['FuelChrg'], "0.49"
    assert_equal resp.params['TotalChrg'], "7.04"
    assert_equal resp.params['SortCode'], "LAX"
    assert resp.params['Tracking'].present?
    assert resp.params['Error'].nil?
  end

  def test_create_shipment_with_Zebra_label
    resp = @carrier.create_shipment(@beverly_hills, @old_honest, @chocolate, label_type: 'ZPL')
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully created shipment"
    assert_equal resp.params['ServiceChrg'], "24.1"
    assert_equal resp.params['FuelChrg'], "3.07"
    assert_equal resp.params['TotalChrg'], "27.17"
    assert_equal resp.params['SortCode'], "LAX"
    assert resp.params['Tracking'].present?
    assert resp.params['Error'].nil?
    assert resp.params['Label']
  end

  def test_create_shipment_with_PDF_label
    resp = @carrier.create_shipment(@beverly_hills, @old_honest, @chocolate, label_type: 'PDF')
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully created shipment"
    assert_equal resp.params['ServiceChrg'], "24.1"
    assert_equal resp.params['FuelChrg'], "3.07"
    assert_equal resp.params['TotalChrg'], "27.17"
    assert_equal resp.params['SortCode'], "LAX"
    assert resp.params['Tracking'].present?
    assert resp.params['Error'].nil?
    assert resp.params['Label']
  end

  def test_create_shipment_error
    mock_response = xml_fixture('on_trac/shipment_error')
    @dishonest = Location.new(@old_honest.to_hash.merge(:postal_code => 'ABCDE'))
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:ssl_post).returns(mock_response)
      @carrier.create_shipment(@beverly_hills, @dishonest, @chocolate)
    end
  end

  def test_find_tracking_info
    mock_response = xml_fixture('on_trac/tracking')
    @carrier.expects(:ssl_get).returns(mock_response)
    resp = @carrier.find_tracking_info(['D10010590135848'])
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully retrieved tracking info"
  end

  def test_find_tracking_details
    mock_response = xml_fixture('on_trac/tracking_details')
    @carrier.expects(:ssl_get).returns(mock_response)
    resp = @carrier.find_tracking_info(['D10010590135856'], :type => :details)
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully retrieved shipment details"
  end

  def test_find_tracking_info_error
    mock_response = xml_fixture('on_trac/tracking_error')
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.expects(:ssl_get).returns(mock_response)
      @carrier.find_tracking_info(['ABCDE123'])
    end
  end
end