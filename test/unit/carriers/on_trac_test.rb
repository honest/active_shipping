require "test_helper"

class OnTracTest < Test::Unit::TestCase
  def setup
    @carrier = OnTrac.new(account: 37, password: 'testpass', test: true)
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @beverly_hills = @locations[:beverly_hills]
    @old_honest = Location.new({
      address1: "1550 17th Street",
      city: "Santa Monica",
      state: "CA",
      postal_code: "90404",
      country: 'US'
    })
    @chocolate = @packages[:chocolate_stuff]
  end

  def test_invalid_rate_credentials
    @carrier = OnTrac.new(account: 37, password: 'badpass', test: true)
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.find_rates(@beverly_hills, @old_honest, [@chocolate])
    end
  end

  def test_find_rates
    resp = @carrier.find_rates(@beverly_hills, @old_honest, [@chocolate])
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully Retrieved rate"
    assert_equal resp.params['ServiceChrg'], "24.1"
    assert_equal resp.params['FuelCharge'], "3.07"
    assert_equal resp.params['TotalCharge'], "27.17"
  end

  def test_find_rates_error
    @dishonest = Location.new(@old_honest.to_hash.merge(postal_code: 'ABCDE'))
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.find_rates(@beverly_hills, @dishonest, [@chocolate])
    end
  end

  def test_zips_success
    zips = @carrier.zips
    assert zips.success?
    assert zips.test
    assert_equal zips.message, "Successfully Retrieved zips"
    assert /\d{5}/.match(zips.params.first[0])
  end

  def test_zips_error
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.zips(Time.now)
    end
  end

  def test_create_shipment
    resp = @carrier.create_shipment(@beverly_hills, @old_honest, @chocolate)
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully created shipment"
    assert_equal resp.params['ServiceChrg'], "24.1"
    assert_equal resp.params['FuelChrg'], "3.07"
    assert_equal resp.params['TotalChrg'], "27.17"
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
    @dishonest = Location.new(@old_honest.to_hash.merge(postal_code: 'ABCDE'))
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.create_shipment(@beverly_hills, @dishonest, @chocolate)
    end
  end

  # def test_find_tracking_info
  #   resp = @carrier.find_tracking_info(['D10010466126749'])
  #   assert resp.success?
  #   assert resp.test
  #   assert_equal resp.message, "Successfully retrieved tracking info"
  # end

  # def test_find_tracking_details
  #   resp = @carrier.find_tracking_info(['D10010466126749'], type: :details)
  #   assert resp.success?
  #   assert resp.test
  #   assert_equal resp.message, "Successfully retrieved shipment details"
  # end

  def test_find_tracking_info_error
    assert_raise ActiveMerchant::Shipping::ResponseError do
      @carrier.find_tracking_info(['ABCDE123'])
    end
  end

  def test_create_and_track_shipment
    resp = @carrier.create_shipment(@beverly_hills, @old_honest, @chocolate)
    assert resp.success?
    tracking_number = resp.params['Tracking']
    resp = @carrier.find_tracking_info([tracking_number])
    assert resp.success?
  end
end