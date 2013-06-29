require "test_helper"

class OnTracTest < Test::Unit::TestCase
  def setup
    @carrier = OnTrac.new(account: 37, password: 'testpass', test: true)
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations

  end

  def test_find_rates
    beverly_hills = @locations[:beverly_hills]
    old_honest = Location.new({
      address1: "1550 17th Street",
      city: "Santa Monica",
      state: "CA",
      postal_code: "90404",
      country: 'US'
    })
    resp = @carrier.find_rates(beverly_hills, old_honest, [@packages[:chocolate_stuff]])
    assert resp.success?
    assert resp.test
    assert_equal resp.message, "Successfully Retrieved rate"
    assert_equal resp.params['ServiceChrg'], "24.1"
    assert_equal resp.params['FuelCharge'], "3.07"
    assert_equal resp.params['TotalCharge'], "27.17"
  end

  # def test_zips_success
  #   zips = @carrier.zips
  #   assert zips.success?
  #   assert zips.test
  #   assert_equal zips.message, "Successfully Retrieved zips"
  #   assert /\d{5}/.match(zips.params.first[0])
  # end

  # def test_zips_error
  #   assert_raise ActiveMerchant::Shipping::ResponseError do
  #     @carrier.zips(Time.now)
  #   end
  # end
end