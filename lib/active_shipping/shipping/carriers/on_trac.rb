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
        puts url
        url
      end

      def build_query_params(params)
        params.map{|key, value| "#{key}=#{CGI.escape(value)}" }.join('&')
      end

      def build_packages(origin, destination, packages)
        packages.map do |package|

        end
      end
    end
  end
end