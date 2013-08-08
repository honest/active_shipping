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

      # def create_shipment_group(shipments, options = {})
      #   options = @options.update(options)

      #   shipment_group_request = build_shipment_group_request(shipments)

      #   response = commit(save_request(shipment_request), (options[:test] || false))

      #   parse_shipment_group_response(response)
      # end

      # def create_linehaul(shipment_groups, options = {})
      #   options = @options.update(options)

      #   linehaul_request = build_linehaul_request(shipment_groups)

      #   response = commit(save_request(linehaul_request), (options[:test] || false))

      #   parse_linehaul_response(response)
      # end

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
            xml.Country destination.country
            xml.Phone destination.phone
            xml.PostalCode destination.postal_code
            xml.Residental destination.address_type == 'residential'
          end
          xml.ShipMethod options[:shipping_methdo] || 'LGINTSTD'
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
                xml.UnitPrice item.value
                xml.Description item.name
                xml.HSCode item.hs_code
                xml.CountryOfOrigin origin.country_code
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
          xml.TrackingNumber tracking_number
        end
      end

      # def build_shipment_group_request(shipments, options)
      #   xml = Builder::XmlMarkup.new
      #   xml.CreateShipmentGroupRequest do
      #     xml.Login do
      #       xml.Username options[:username]
      #       xml.Password options[:password]
      #     end
      #     if options[:region].present?
      #       xml.Region options[:region]
      #     end
      #     xml.Test options[:test]
      #     xml.AddToExistingGroup options[:existing_group] || false
      #     if options[:group] == 'specific'
      #       xml.Shipments do
      #       end
      #     else
      #     end
      #   end     
      # end

      # def build_linehaul_request(shipment_groups, options)
      #   xml = Builder::XmlMarkup.new
      #   xml.LinehaulRequest do
      #     xml.Login do
      #       xml.Username options[:username]
      #       xml.Password options[:password]
      #     end
      #     xml.ShipmentGroups do
      #     end
      #     xml.GenerateLabel options[:label] || true
      #     xml.LabelFormat options[:label_format] || 'PDF'
      #     xml.Packages do
      #     end
      #   end
      # end

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
          package = result['Result']['Packages']['Package']
          #To handle that fact that with one event it parses as a hash.
          events = [package['Events']['Event']].flatten
          shipment_events = events.map do |event|
            time = Time.parse(event['DateTime'].gsub(/(\d{2})\/(\d{2})/, '\2/\1'))
            ShipmentEvent.new(event['Status'], time.utc, event['Location'])
          end
          details = {
            xml: response,
            carrier: @@name,
            status: :success,
            test: test_mode?,
            shipment_events: shipment_events,
            tracking_number: package['TrackingNumber']
          }
          if package['ExpectedDelivery'].present?            
            details[:scheduled_delivery_date] = Date.parse(package['ExpectedDelivery'])
          end
          TrackingResponse.new(true, 'Successfully received package data', result, details)
        end
      end

      # def parse_shipment_group_response(response, options)
      #   result = Hash.from_xml(response)['CreateShipmentGroupResponse']
      #   if result['Errors']
      #     parse_error(ShippingResponse, result)
      #   else
      #     details = result['Result']
      #     ids = result['ShipmentGroups']['ShipmentGroup'].map{|group| group['ID'] }
      #     ShippingResponse.new(true, details['ResultMessage'], {
      #       test: test_mode?,
      #       status: :error,
      #       carrier_name: @@name,
      #       shipping_ids: ids,
      #       number_of_shipments: details['NumberOfShipments']
      #     })
      #   end  
      # end

      # def parse_linehaul_response(response, options)
      #   result = Hash.from_xml(response)['CreateShipmentGroupResponse']
      #   if result['Errors']
      #     parse_error(ShippingResponse, result)
      #   else
      #     details = result['Result']
      #     details['Packages']['Package'].map do |shipment|
      #       ShippingResponse.new(true, shipment, {
      #         test: test_mode?,
      #         status: :error,
      #         carrier_name: @@name,
      #         tracking_number: shipment['TrackingNumber'],
      #         shipping_id: shipment['LabelLink']
      #       })
      #     end
      #   end  
      # end

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