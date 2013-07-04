# -*- coding: utf-8 -*-
module ActiveMerchant
  module Shipping
    class OnTrac < Carrier
      cattr_reader :name
      cattr_reader :label_type

      @@name = "On Trac"

      TEST_URL = 'https://www.shipontrac.net/OnTracTestWebServices/OnTracServices.svc'
      LIVE_URL = 'https://www.shipontrac.net/OnTracWebServices/OnTracServices.svc'

      SERVICES = {
        'S' => 'Sunrise',
        'G' => 'Gold',
        'H' => 'Palletized Freight',
        'C' => 'OnTrac Ground'
      }

      def requirements
        [:account, :password]
      end

      def find_rates(origin, destination, packages, options = {})
        url = build_url("/V1/#{@options[:account]}/rates", {
          :pw => @options[:password],
          :packages => build_packages(origin, destination, packages, options)
        })
        response = Hash.from_xml(save_request(ssl_get(url)))['OnTracRateResponse']
        error = response['Error'] || response['Shipments']['Shipment']['Error']
        if error.present?
          RateResponse.new(false, error, {}, {:test => test_mode?})
        else
          details = response['Shipments']['Shipment']['Rates']['Rate']
          service_name  = SERVICES[details['Service']]
          options = {
            :service_charge => details['ServiceChrg'],
            :fuel_charge => details['FuelCharge'],
            :total_charge => details['TotalCharge'],
            :transit_days => details['TransitDays'],
            :global_rate => details['GlobalRate']
          }
          rate = RateEstimate.new(origin, destination, @@name, service_name, options)
          RateResponse.new(true, 'Successfully Retrieved rate', details, {
            :rates => [rate],
            :test => test_mode?
          })
        end
      end

      def create_shipment(origin, destination, package, options = {})
        url = build_url("/V1/#{@options[:account]}/shipments", {
          :pw => @options[:password]
        })
        shipment = build_shipment(origin, destination, package, options)
        result = save_request(ssl_post(url, shipment))
        response = Hash.from_xml(result)['OnTracShipmentResponse']
        error = response['Error'] || response['Shipments']['Shipment']['Error']
        if error.present?
          ShippingResponse.new(false, error, {}, {:test => test_mode?})
        else
          details = response['Shipments']['Shipment']
          ShippingResponse.new(true, 'Successfully created shipment', details, {
            :test => test_mode?,
            :tracking_number => details['Tracking'],
            :shipping_id => details['UID'],
            :label => details['Label']
          })
        end
      end

      # get shipment
      # optional params
      # logoFormat {BMP,GIF,PNG, and JPG}
      # sigFormat {BMP,GIF,PNG, and JPG}
      def find_tracking_info(tracking_numbers, options = {})
        type = options.delete(:type) || :track
        url = build_url("/V1/#{@options[:account]}/shipments", {
          :pw => @options[:password],
          :requestType => type,
          :tn => tracking_numbers.class == String ? tracking_numbers : tracking_numbers.join(',')
        }.merge(options))
        result = Hash.from_xml(save_request(ssl_get(url)))
        response = case type.to_sym
        when :details then
          result['OnTracUpdateResponse']
        when :track
          result['OnTracTrackingResult']
        end
        default_options = {
          :carrier                 => @@name,
          :test                    => test_mode?
        }
        error = response['Error'] || response['Shipments']['Shipment']['Error']
        if error
          TrackingResponse.new(false, error, {}, default_options)
        else
          details = response['Shipments']['Shipment']
          case type.to_sym
          when :details then
            msg = 'Successfully retrieved shipment details'
            options = default_options.merge({
              :tracking_number => details['Tracking']
            })
            TrackingResponse.new(true, msg, details, options)
          when :track then
            default_options.merge!(:service_name => SERVICES[details['Service'].strip])
            msg = 'Successfully retrieved tracking info'
            if result['OnTracTrackingResult']['Logo'].present?
              details.merge(logo: result['OnTracTrackingResult']['Logo'])
            else
              event = details['Events']['Event']
              location = Location.new({
                name: event['Facility'].strip,
                city: event['City'],
                state: event['State'],
                postal_code: event['Zip']
              })
              time = Time.parse(event['EventTime'])
              zoneless_time = Time.utc(time.year, time.month, time.mday, time.hour, time.min, time.sec)
              ship_event = ShipmentEvent.new(event['Description'], zoneless_time, location)
              destination = Location.new({
                name: details['Name'],
                address1: details['Addr1'],
                city: details['City'],
                state: details['State'],
                postal_code: details['Zip']
              })
              options = default_options.merge({
                :shipment_events         => [ship_event],
                :tracking_number         => details['Tracking'],
                :origin                  => Location.new({}),
                :destination             => destination,
                :delivery_signature      => details['Signature'],
              })
              TrackingResponse.new(true, msg, details, options)
            end
          end
        end
      end

      def zips(last_update = nil)
        params = {pw: @options[:password]}
        params.merge!(lastUpdate: last_update.strftime('%Y-%m-%d')) unless last_update.nil?
        url = build_url("/V1/#{@options[:account]}/Zips", params)
        response = Hash.from_xml(save_request(ssl_get(url)))['OnTracZipResponse']
        if response['Error'].present?
          Response.new(false, response['Error'], {}, {:test => test_mode?})
        else
          zips = response['Zips']['Zip'].inject({}) do |hsh, zip_info|
            zip = zip_info.delete('zipCode')
            hsh.merge(zip => zip_info)
          end
          Response.new(true, 'Successfully Retrieved zips', zips, {:test => test_mode?})
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
        packages.map do |package|
          dimensions = [:length, :width, :height].map{|axis| package.inches(axis) }.join('x')
          data = [
            options[:id] || SecureRandom.uuid, #unique id
            origin.postal_code, # origin postal code
            destination.postal_code, # destination postal code
            options[:residential] || false, # residential
            options[:cod] || '0.00', # COD
            options[:saturday_delivery] || false, # Saturday Delivery
            package.value || 0, # declared value
            package.lbs, # weight
            dimensions, # dimensions
            options[:service] || 'C', # service S – Sunrise, G – Gold, H – Palletized Freight, C – OnTrac Ground
          ]
          data.join(';')
        end.join(',')
      end

      def build_label_type(options={})
        # 0 – No label, 1 – pdf, 2 – jpg, 3 – bmp, 4 – gif, 5 – 4 x 3 EPL, 6 – 4 x 5 EPL label, 7 – 4 x 5 ZPL
        if options[:label_type].present?
          return 1 if [1, 'PDF', 'pdf'].include?(options[:label_type])
        end
        if options[:label_type].present?
          return 7 if [7, 'ZPL', 'zpl'].include?(options[:label_type])
        end
        return 0
      end

      def build_shipment(origin, destination, package, options = {})
        xml = Builder::XmlMarkup.new
        xml.OnTracShipmentRequest do
          xml.Shipments do
            xml.Shipment do
              xml.UID(options[:id] || SecureRandom.uuid)
              xml.shipper do
                xml.Name(origin.name)
                xml.Addr1(origin.address1)
                # xml.Addr2(origin.address2)
                # xml.Addr3(origin.address3)
                xml.City(origin.city)
                xml.State(origin.state)
                xml.Zip(origin.zip)
                xml.Contact
                xml.Phone(origin.phone)
              end
              xml.consignee do
                xml.Name(destination.name)
                xml.Addr1(destination.address1)
                xml.Addr2(destination.address2)
                xml.Addr3(destination.address3)
                xml.City(destination.city)
                xml.State(destination.state)
                xml.Zip(destination.zip)
                xml.Contact
                xml.Phone(destination.phone)
              end
              xml.Service(options[:service] || 'C')
              xml.SignatureRequired(options[:signatured_required] || false)
              xml.Residential(options[:residential] || false)
              xml.SaturdayDel(options[:saturday_delivery] || false)
              xml.Declared(package.value || 0)
              xml.COD(options[:cod]|| 0.0)
              xml.CODType(options[:cod_type] || 'NONE')
              xml.Weight(package.lbs)
              xml.BillTo(options[:bill_to] || 0)
              xml.Instructions(options[:instructions] || '')
              xml.Reference(options[:reference])
              xml.Reference2
              xml.Reference3
              xml.Tracking
              xml.ShipEmail
              xml.DelEmail
              xml.DIM do
                xml.Length(package.inches(:length))
                xml.Width(package.inches(:width))
                xml.Height(package.inches(:height))
              end
              xml.LabelType(build_label_type(@options.merge(options)))
              xml.ShipDate(options[:ship_date] || Time.now.strftime('%Y-%m-%d'))
            end
          end
        end
      end
    end
  end
end
