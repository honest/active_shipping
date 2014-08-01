# -*- coding: utf-8 -*-
module ActiveMerchant
  module Shipping
    class Landmark < Carrier
      cattr_reader :name

      URL = 'https://mercury.landmarkglobal.com/api/api.php'

      @@name = "Landmark"

      def requirements
        [:username, :password]
      end

      def find_tracking_info(tracking_number, options = {})
        options = @options.update(options)

        tracking_request = build_tracking_request(tracking_number, options)

        response = commit(save_request(tracking_request), (options[:test] || false))

        parse_tracking_response(response, options)
      end

      def create_shipment(origin, destination, package, package_items = [], options = {})
        options = @options.update(options)

        shipment_request = build_shipment_request(origin, destination, package, package_items, options)

        response = commit(save_request(shipment_request), (options[:test] || false))

        parse_shipping_response(response, options.merge(package: package, items: package_items))
      end

      def create_shipment_group(shipments, options = {})
        options = @options.update(options)

        shipment_group_request = build_shipment_group_request(shipments, options)

        response = commit(save_request(shipment_group_request), (options[:test] || false))

        parse_shipment_group_response(response, options)
      end

      protected

      def build_shipment_request(origin, destination, package, package_items, options)
        xml = Builder::XmlMarkup.new
        xml.ShipRequest do
          xml.Login do
            xml.Username options[:username]
            xml.Password options[:password]
          end
          xml.Test options[:test]
          xml.Reference options[:reference] || SecureRandom.hex(6)
          xml.ShipTo do
            xml.Name destination.name || 'Test'
            xml.Address1 destination.address1
            xml.Address2 destination.address2
            xml.City destination.city
            xml.State destination.state
            xml.Country destination.country.code(:alpha2)
            xml.Phone destination.phone
            xml.PostalCode destination.postal_code
            xml.Region destination.country
            xml.Residental destination.address_type == 'residential'
          end
          xml.ShipMethod options[:shipping_method] || 'LGINTSTD'
          xml.LabelFormat options[:label_format] || 'PDF'
          xml.Packages do
            xml.Package do
              xml.Weight package.lbs
              xml.Length package.inches(:length)
              xml.Width package.inches(:width)
              xml.Height package.inches(:height)
            end
          end
          xml.Items do
            package_items.each do |item|
              xml.Item do
                xml.Sku item.sku
                xml.Quantity item.quantity || 1
                xml.UnitPrice item.value.to_f / 100 # Landmark uses dollars, PackageItem uses cents
                xml.Description item.name
                xml.HSCode item.hs_code
                xml.CountryOfOrigin item.options[:country_of_origin] || origin.country_code
              end
            end
          end
        end
      end

      def build_tracking_request(tracking_number, options)
        xml = Builder::XmlMarkup.new
        xml.TrackRequest do
          xml.Login do
            xml.Username options[:username]
            xml.Password options[:password]
          end
          xml.Test options[:test]
          if options[:reference]
            xml.Reference tracking_number
          else
            xml.TrackingNumber tracking_number
          end
          if options[:include_historical_events]
            xml.RetrievalType "Historical"
          end
        end
      end

      def build_shipment_group_request(shipments, options)
        xml = Builder::XmlMarkup.new
        xml.CreateShipmentGroupRequest do
          xml.Login do
            xml.Username options[:username]
            xml.Password options[:password]
          end
          if options[:region].present?
            xml.Region options[:region]
          end
          xml.Test options[:test]
          xml.AddToExistingGroup options[:existing_group].present? || false
          if options[:existing_group] == 'specific'
            xml.Shipments do
              shipments.each do |shipment|
                xml.Shipment do
                  xml.PackageReference shipment
                end
              end
            end
          else
          end
        end
      end

      def parse_shipping_response(response, options)
        result = Hash.from_xml(response)['ShipResponse']
        if result['Errors']
          parse_error(ShippingResponse, result)
        else
          details = result['Result']
          package = details['Packages']['Package']
          ShippingResponse.new(true, 'Successfully created shipment', result, {
            xml: response,
            test: test_mode?,
            status: :success,
            carrier: @@name,
            label: package['LabelLink'],
            tracking_number: package['TrackingNumber'],
            shipping_id: package['PackageID'],
            barcode_data: package['BarcodeData']
          })
        end
      end

      def parse_tracking_response(response, options)
        result = Hash.from_xml(response)['TrackResponse']
        if result['Errors']
          parse_error(TrackingResponse, result)
        else
          package_data = result['Result']['Packages']['Package']
          wrapped_package = Array.wrap(package_data)
          shipment_events = wrapped_package.map do |package|
            #To handle that fact that with one event it parses as a hash.
            events = [package['Events']['Event']].flatten
            shipment_events = events.map do |event|
              time = Time.parse(event['DateTime'].gsub(/(\d{2})\/(\d{2})/, '\2/\1'))
              shipment_event = ShipmentEvent.new(event['Status'], time, event['Location'])
              shipment_event.data = event
              shipment_event
            end
          end
          expected_delivery = wrapped_package.map{|package| package['ExpectedDelivery']}.compact.max
          tracking_numbers = wrapped_package.map{|package| package['TrackingNumber']}.compact
          details = {
            xml: response,
            carrier: @@name,
            status: :success,
            test: test_mode?,
            shipment_events: shipment_events.flatten,
            tracking_number: tracking_numbers,
            scheduled_delivery_date: expected_delivery
          }
          TrackingResponse.new(true, 'Successfully received package data', result, details)
        end
      end

      def parse_shipment_group_response(response, options)
        result = Hash.from_xml(response)['CreateShipmentGroupResponse']
        if result['Errors']
          parse_error(ShippingResponse, result)
        else
          details = result['Result']
          ids = result['ShipmentGroups']['ShipmentGroup'].map{|group| group['ID'] }
          ShippingResponse.new(true, details['ResultMessage'], {
            test: test_mode?,
            status: :error,
            carrier_name: @@name,
            shipping_ids: ids,
            number_of_shipments: details['NumberOfShipments']
          })
        end
      end

      def parse_error(klass, result)
        errors = [result['Errors']['Error']].flatten
        messages = errors.map{|err| err['ErrorMessage']}.join(',')
        status_codes =  errors.map{|err| err['ErrorCode']}.join(',')
        klass.new(false, messages, result, {
          test: test_mode?,
          status: :error,
          carrier: @@name,
          status_code: status_codes,
          status_description: messages
        })
      end

      def commit(request, test = false)
        ssl_post(URL, request)
      end
    end
  end
end
