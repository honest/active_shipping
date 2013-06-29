module ActiveMerchant
  module Shipping
    class OnTrac < Carrier      
      cattr_reader :name
      @@name = "On Trac"
      
      TEST_URL = 'https://www.shipontrac.net/OnTracTestWebServices/OnTracServices.svc'
      LIVE_URL = 'https://www.shipontrac.net/OnTracWebServices/OnTracServices.svc'

      def requirements
        [:account, :password]
      end

      def find_rates(origin, destination, packages, options = {})
        url = build_url("/V1/#{@options[:account]}/rates", {
          pw: @options[:password],
          packages: build_packages(origin, destination, packages, options)
        })
        response = Hash.from_xml(save_request(ssl_get(url)))['OnTracRateResponse']
        if response['Error']
          Response.new(false, response['Error'], {}, {test: test_mode?})
        else
          details = response['Shipments']['Shipment']['Rates']['Rate']
          Response.new(true, 'Successfully Retrieved rate', details, {test: test_mode?})
        end
      end

      def create_shipment(origin, destination, packages, options = {})
        
      end

      # get shipment
      def find_tracking_info(tracking_number, options={})

      end

      def create_label(origin, destination, packages, options = {})
        
      end

      def zips(last_update = nil)
        params = {pw: @options[:password]}
        params.merge!(lastUpdate: last_update.strftime('%Y-%m-%d')) unless last_update.nil?
        url = build_url("/V1/#{@options[:account]}/Zips", params)
        response = Hash.from_xml(save_request(ssl_get(url)))['OnTracZipResponse']
        if response['Error']
          Response.new(false, response['Error'], {}, {test: test_mode?})
        else
          zips = response['Zips']['Zip'].inject({}) do |hsh, zip_info|
            zip = zip_info.delete('zipCode')
            hsh.merge(zip => zip_info)
          end
          Response.new(true, 'Successfully Retrieved zips', zips, {test: test_mode?})
        end
      end

      protected

      def build_url(path, options)
        url = test_mode? ? TEST_URL : LIVE_URL
        url += path
        url += "?#{build_query_params(options)}"
        url
      end

      def build_query_params(params)
        params.map{|key, value| "#{key}=#{value}" }.join('&')
      end

      def build_packages(origin, destination, packages, options = {})
        imperial = ['US','LR','MM'].include?(origin.country_code(:alpha2))
        packages.map do |package|
          dimensions = [:length, :width, :height].map do |axis|
            units = imperial ? :inches : :cm
            package.send(units, axis)
          end.join('x')
          data = [
            SecureRandom.uuid, #unique id
            origin.postal_code, # origin postal code
            destination.postal_code, # destination postal code
            false, # residential
            '0.00', # COD
            false, # Saturday Delivery
            package.value || 0, # declared value
            imperial ? package.lbs : package, # weight
            dimensions, # dimensions
            'S', # service S – Sunrise, G – Gold, H – Palletized Freight, C – OnTrac Ground
          ]
          data.join(';')
        end.join(',')
      end
    end
  end
end