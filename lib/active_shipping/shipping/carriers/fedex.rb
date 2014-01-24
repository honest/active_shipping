# FedEx module by Jimmy Baker
# http://github.com/jimmyebaker

require 'date'
require 'active_support/json'

module ActiveMerchant
  module Shipping
    
    # :key is your developer API key
    # :password is your API password
    # :account is your FedEx account number
    # :login is your meter number
    class FedEx < Carrier
      self.retry_safe = true
      
      cattr_reader :name
      @@name = "FedEx"
      
      TEST_URL = 'https://gatewaybeta.fedex.com:443/xml'
      LIVE_URL = 'https://gateway.fedex.com:443/xml'
      
      CarrierCodes = {
        "fedex_ground" => "FDXG",
        "fedex_express" => "FDXE"
      }
      
      ServiceTypes = {
        "PRIORITY_OVERNIGHT" => "FedEx Priority Overnight",
        "PRIORITY_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx Priority Overnight Saturday Delivery",
        "FEDEX_2_DAY" => "FedEx 2 Day",
        "FEDEX_2_DAY_SATURDAY_DELIVERY" => "FedEx 2 Day Saturday Delivery",
        "STANDARD_OVERNIGHT" => "FedEx Standard Overnight",
        "FIRST_OVERNIGHT" => "FedEx First Overnight",
        "FIRST_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx First Overnight Saturday Delivery",
        "FEDEX_EXPRESS_SAVER" => "FedEx Express Saver",
        "FEDEX_1_DAY_FREIGHT" => "FedEx 1 Day Freight",
        "FEDEX_1_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 1 Day Freight Saturday Delivery",
        "FEDEX_2_DAY_FREIGHT" => "FedEx 2 Day Freight",
        "FEDEX_2_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 2 Day Freight Saturday Delivery",
        "FEDEX_3_DAY_FREIGHT" => "FedEx 3 Day Freight",
        "FEDEX_3_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 3 Day Freight Saturday Delivery",
        "INTERNATIONAL_PRIORITY" => "FedEx International Priority",
        "INTERNATIONAL_PRIORITY_SATURDAY_DELIVERY" => "FedEx International Priority Saturday Delivery",
        "INTERNATIONAL_ECONOMY" => "FedEx International Economy",
        "INTERNATIONAL_FIRST" => "FedEx International First",
        "INTERNATIONAL_PRIORITY_FREIGHT" => "FedEx International Priority Freight",
        "INTERNATIONAL_ECONOMY_FREIGHT" => "FedEx International Economy Freight",
        "GROUND_HOME_DELIVERY" => "FedEx Ground Home Delivery",
        "FEDEX_GROUND" => "FedEx Ground",
        "INTERNATIONAL_GROUND" => "FedEx International Ground"
      }

      PackageTypes = {
        "fedex_envelope" => "FEDEX_ENVELOPE",
        "fedex_pak" => "FEDEX_PAK",
        "fedex_box" => "FEDEX_BOX",
        "fedex_tube" => "FEDEX_TUBE",
        "fedex_10_kg_box" => "FEDEX_10KG_BOX",
        "fedex_25_kg_box" => "FEDEX_25KG_BOX",
        "your_packaging" => "YOUR_PACKAGING"
      }

      DropoffTypes = {
        'regular_pickup' => 'REGULAR_PICKUP',
        'request_courier' => 'REQUEST_COURIER',
        'dropbox' => 'DROP_BOX',
        'business_service_center' => 'BUSINESS_SERVICE_CENTER',
        'station' => 'STATION'
      }

      PaymentTypes = {
        'sender' => 'SENDER',
        'recipient' => 'RECIPIENT',
        'third_party' => 'THIRDPARTY',
        'collect' => 'COLLECT'
      }
      
      PackageIdentifierTypes = {
        'tracking_number' => 'TRACKING_NUMBER_OR_DOORTAG',
        'door_tag' => 'TRACKING_NUMBER_OR_DOORTAG',
        'rma' => 'RMA',
        'ground_shipment_id' => 'GROUND_SHIPMENT_ID',
        'ground_invoice_number' => 'GROUND_INVOICE_NUMBER',
        'ground_customer_reference' => 'GROUND_CUSTOMER_REFERENCE',
        'ground_po' => 'GROUND_PO',
        'express_reference' => 'EXPRESS_REFERENCE',
        'express_mps_master' => 'EXPRESS_MPS_MASTER'
      }


      TransitTimes = ["UNKNOWN","ONE_DAY","TWO_DAYS","THREE_DAYS","FOUR_DAYS","FIVE_DAYS","SIX_DAYS","SEVEN_DAYS","EIGHT_DAYS","NINE_DAYS","TEN_DAYS","ELEVEN_DAYS","TWELVE_DAYS","THIRTEEN_DAYS","FOURTEEN_DAYS","FIFTEEN_DAYS","SIXTEEN_DAYS","SEVENTEEN_DAYS","EIGHTEEN_DAYS"]

      # FedEx tracking codes as described in the FedEx Tracking Service WSDL Guide
      # All delays also have been marked as exceptions
      TRACKING_STATUS_CODES = HashWithIndifferentAccess.new({
        'AA' => :at_airport,
        'AD' => :at_delivery,
        'AF' => :at_fedex_facility,
        'AR' => :at_fedex_facility,
        'AP' => :at_pickup,
        'CA' => :canceled,
        'CH' => :location_changed,
        'DE' => :exception,
        'DL' => :delivered,
        'DP' => :departed_fedex_location,
        'DR' => :vehicle_furnished_not_used,
        'DS' => :vehicle_dispatched,
        'DY' => :exception,
        'EA' => :exception,
        'ED' => :enroute_to_delivery,
        'EO' => :enroute_to_origin_airport,
        'EP' => :enroute_to_pickup,
        'FD' => :at_fedex_destination,
        'HL' => :held_at_location,
        'IT' => :in_transit,
        'LO' => :left_origin,
        'OC' => :order_created,
        'OD' => :out_for_delivery,
        'PF' => :plane_in_flight,
        'PL' => :plane_landed,
        'PU' => :picked_up,
        'RS' => :return_to_shipper,
        'SE' => :exception,
        'SF' => :at_sort_facility,
        'SP' => :split_status,
        'TR' => :transfer
      })

      def self.service_name_for_code(service_code)
        ServiceTypes[service_code] || "FedEx #{service_code.titleize.sub(/Fedex /, '')}"
      end
      
      def requirements
        [:key, :password, :account, :login]
      end
      
      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        
        rate_request = build_rate_request(origin, destination, packages, options)
        
        xml = commit(save_request(rate_request), (options[:test] || false))
        response = remove_version_prefix(xml)

        parse_rate_response(origin, destination, packages, response, options)
      end
      
      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        
        tracking_request = build_tracking_request(tracking_number, options)

        xml = commit(save_request(tracking_request), (options[:test] || false))
        response = remove_version_prefix(xml)
        parse_tracking_response(response, options)
      end

      def create_shipment(origin, destination, package, options = {})
        options = @options.update(options)

        shipment_request = build_shipment_request(origin, destination, package, options)

        response = commit(save_request(shipment_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')

        parse_shipping_response(response, options.merge(package: package))
      end

      def validate_address(location, options = {})
        options = @options.update(options)

        validation_request = build_validation_request(location, options)
        response = commit(save_request(validation_request), options[:test] || false).gsub(/<\?.*\?>/, "").strip.gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')

        parse_validation_response(response, options)
      end

      protected

      def build_rate_request(origin, destination, packages, options={})
        imperial = ['US','LR','MM'].include?(origin.country_code(:alpha2))

        xml_request = XmlNode.new('RateRequest', 'xmlns' => 'http://fedex.com/ws/rate/v6') do |root_node|
          root_node << build_request_header

          # Version
          root_node << XmlNode.new('Version') do |version_node|
            version_node << XmlNode.new('ServiceId', 'crs')
            version_node << XmlNode.new('Major', '6')
            version_node << XmlNode.new('Intermediate', '0')
            version_node << XmlNode.new('Minor', '0')
          end
          
          # Returns delivery dates
          root_node << XmlNode.new('ReturnTransitAndCommit', true)
          # Returns saturday delivery shipping options when available
          root_node << XmlNode.new('VariableOptions', 'SATURDAY_DELIVERY')
          
          root_node << XmlNode.new('RequestedShipment') do |rs|
            rs << XmlNode.new('ShipTimestamp', ship_timestamp(options[:turn_around_time]))
            rs << XmlNode.new('DropoffType', options[:dropoff_type] || 'REGULAR_PICKUP')
            rs << XmlNode.new('PackagingType', options[:packaging_type] || 'YOUR_PACKAGING')
            
            rs << build_location_node('Shipper', (options[:shipper] || origin))
            rs << build_location_node('Recipient', destination)
            if options[:shipper] and options[:shipper] != origin
              rs << build_location_node('Origin', origin)
            end
            
            rs << XmlNode.new('RateRequestTypes', 'ACCOUNT')
            rs << XmlNode.new('PackageCount', packages.size)
            packages.each do |pkg|
              rs << XmlNode.new('RequestedPackages') do |rps|
                rps << XmlNode.new('Weight') do |tw|
                  tw << XmlNode.new('Units', imperial ? 'LB' : 'KG')
                  tw << XmlNode.new('Value', [((imperial ? pkg.lbs : pkg.kgs).to_f*1000).round/1000.0, 0.1].max)
                end
                rps << XmlNode.new('Dimensions') do |dimensions|
                  [:length,:width,:height].each do |axis|
                    value = ((imperial ? pkg.inches(axis) : pkg.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
                    dimensions << XmlNode.new(axis.to_s.capitalize, value.ceil)
                  end
                  dimensions << XmlNode.new('Units', imperial ? 'IN' : 'CM')
                end
              end
            end
            
          end
        end
        xml_request.to_s
      end
      
      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('TrackRequest', 'xmlns' => 'http://fedex.com/ws/track/v3') do |root_node|
          root_node << build_request_header
          
          # Version
          root_node << XmlNode.new('Version') do |version_node|
            version_node << XmlNode.new('ServiceId', 'trck')
            version_node << XmlNode.new('Major', '3')
            version_node << XmlNode.new('Intermediate', '0')
            version_node << XmlNode.new('Minor', '0')
          end
          
          root_node << XmlNode.new('PackageIdentifier') do |package_node|
            package_node << XmlNode.new('Value', tracking_number)
            package_node << XmlNode.new('Type', PackageIdentifierTypes[options['package_identifier_type'] || 'tracking_number'])
          end
          
          root_node << XmlNode.new('ShipDateRangeBegin', options['ship_date_range_begin']) if options['ship_date_range_begin']
          root_node << XmlNode.new('ShipDateRangeEnd', options['ship_date_range_end']) if options['ship_date_range_end']
          root_node << XmlNode.new('IncludeDetailedScans', 1)
        end
        xml_request.to_s
      end

      def build_shipment_request(origin, destination, package, options = {})
        imperial = ['US','LR','MM'].include?(origin.country_code(:alpha2))

        xml_request = XmlNode.new('ProcessShipmentRequest', 'xmlns' => 'http://fedex.com/ws/ship/v12') do |root_node|
          root_node << build_request_header

          # Version
          root_node << XmlNode.new('Version') do |version_node|
            version_node << XmlNode.new('ServiceId', 'ship')
            version_node << XmlNode.new('Major', '12')
            version_node << XmlNode.new('Intermediate', '0')
            version_node << XmlNode.new('Minor', '0')
          end

          # Start the request for shipment
          root_node << XmlNode.new('RequestedShipment') do |request_node|
            # Start with the headers on the shipment
            request_node << XmlNode.new('ShipTimestamp', Time.now.utc.iso8601(2))
            request_node << XmlNode.new('DropoffType', options[:dropoff_type] || 'REGULAR_PICKUP')
            request_node << XmlNode.new('ServiceType', options[:service_type] || 'FEDEX_GROUND')
            request_node << XmlNode.new('PackagingType', options[:packaging_type] || 'YOUR_PACKAGING')

            request_node << build_shipping_location_node('Shipper', origin)
            request_node << build_shipping_location_node('Recipient', destination)

            request_node << XmlNode.new('ShippingChargesPayment') do |scp|
              scp << XmlNode.new('PaymentType', options[:payment_type] || 'SENDER')
              scp << XmlNode.new('Payor') do |payor|
                payor << XmlNode.new('ResponsibleParty') do |party|
                  party << XmlNode.new('AccountNumber', options[:account])
                  party << XmlNode.new('Contact') do |contact|
                    contact << XmlNode.new('PersonName', origin.name || 'Shipper')
                    contact << XmlNode.new('CompanyName', origin.company_name || 'Company')
                    contact << XmlNode.new('PhoneNumber', origin.phone) if origin.phone.present?
                  end
                end
              end
            end

            if options[:service_type] == 'SMART_POST' && options[:smart_post].present?
              request_node << XmlNode.new('SmartPostDetail') do |smart_post|
                smart_post << XmlNode.new('Indicia', options[:smart_post][:indicia] || 'PARCEL_SELECT')
                if options[:smart_post][:ancillary_endorsement]
                  smart_post << XmlNode.new('AncillaryEndorsement', options[:smart_post][:ancillary_endorsement]) 
                end
                smart_post << XmlNode.new('HubId', options[:smart_post][:hub_id])
              end
            end

            request_node << XmlNode.new('LabelSpecification') do |ls|
              ls << XmlNode.new('LabelFormatType', options[:label_format_type] || 'COMMON2D')
              ls << XmlNode.new('ImageType', options[:label_image_type] || 'PDF')
              ls << XmlNode.new('LabelStockType', options[:label_stock_type] || 'PAPER_LETTER')
              ls << XmlNode.new('CustomerSpecifiedDetail') do |csd|
                csd << XmlNode.new('MaskedData', 'SHIPPER_ACCOUNT_NUMBER')
              end
            end

            request_node << XmlNode.new('RateRequestTypes','ACCOUNT')
            request_node << XmlNode.new('PackageCount', 1)
            #request_node << XmlNode.new('PackageDetail', 'INDIVIDUAL_PACKAGES')
            request_node << XmlNode.new('RequestedPackageLineItems') do |rps|
              rps << XmlNode.new('SequenceNumber', 1)
              if options[:insured_value]
                rps << XmlNode.new('InsuredValue') do |iv|
                  iv << XmlNode.new('Currency', options[:insured_currency] || 'USD')
                  iv << XmlNode.new('Amount', options[:insured_value])
                end
              end
              rps << XmlNode.new('Weight') do |tw|
                tw << XmlNode.new('Units', imperial ? 'LB' : 'KG')
                 tw << XmlNode.new('Value', imperial ? package.lbs : package.kgs)
              end
              rps << XmlNode.new('Dimensions') do |dimensions|
                [:length,:width,:height].each do |axis|
                  value = ((imperial ? package.inches(axis) : package.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
                  dimensions << XmlNode.new(axis.to_s.capitalize, value.ceil)
                end
                dimensions << XmlNode.new('Units', imperial ? 'IN' : 'CM')
              end
            end
          end
        end
        xml_request.to_s
      end

      def build_request_header
        web_authentication_detail = XmlNode.new('WebAuthenticationDetail') do |wad|
          wad << XmlNode.new('UserCredential') do |uc|
            uc << XmlNode.new('Key', @options[:key])
            uc << XmlNode.new('Password', @options[:password])
          end
        end
        
        client_detail = XmlNode.new('ClientDetail') do |cd|
          cd << XmlNode.new('AccountNumber', @options[:account])
          cd << XmlNode.new('MeterNumber', @options[:login])
          localization_detail = XmlNode.new('Localization') do |ld|
            ld << XmlNode.new('LanguageCode', 'en')
            ld << XmlNode.new('LocaleCode', 'us')
          end
          cd << localization_detail
        end


        
        trasaction_detail = XmlNode.new('TransactionDetail') do |td|
          td << XmlNode.new('CustomerTransactionId', 'ActiveShipping') # TODO: Need to do something better with this..
        end
        
        [web_authentication_detail, client_detail, trasaction_detail]
      end

      def build_shipping_location_node(name, location)
        location_node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('Contact') do |contact_node|
            contact_node << XmlNode.new('PersonName', location.name || name)
            contact_node << XmlNode.new('CompanyName', location.company_name)
            contact_node << XmlNode.new('PhoneNumber', location.phone || '555-555-5555')
          end
          xml_node << XmlNode.new('Address') do |address_node|
            address_node << XmlNode.new('StreetLines', location.address1)
            address_node << XmlNode.new('StreetLines', location.address2)
            address_node << XmlNode.new('City', location.city)
            # Eventually make this respect Canada too
            address_node << XmlNode.new('StateOrProvinceCode', location.state)
            address_node << XmlNode.new('PostalCode', location.postal_code)
            address_node << XmlNode.new('CountryCode', location.country_code(:alpha2))
            # If FedEX GROUND_HOME_DELIVERY service is used then the address needs to be marked residential
            address_node << XmlNode.new('Residential', !location.commercial?)
          end
        end
      end
            
      def build_location_node(name, location)
        location_node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('Address') do |address_node|
            address_node << XmlNode.new('PostalCode', location.postal_code)
            address_node << XmlNode.new("CountryCode", location.country_code(:alpha2))

            address_node << XmlNode.new("Residential", true) unless location.commercial?
          end
        end
      end

      def build_validation_request(location, options)
        xml_request = XmlNode.new('AddressValidationRequest', xmlns: 'http://fedex.com/ws/addressvalidation/v2') do |root_node|
          root_node << build_request_header
          root_node << XmlNode.new('Version') do |version|
            version << XmlNode.new('ServiceId', 'aval')
            version << XmlNode.new('Major', 2)
            version << XmlNode.new('Intermediate', 0)
            version << XmlNode.new('Minor', 0)
          end
          root_node << XmlNode.new('RequestTimestamp', Time.now.as_json)
          root_node << XmlNode.new('Options') do |opt|
            opt << XmlNode.new('CheckResidentialStatus', true)
          end
          root_node << XmlNode.new('AddressesToValidate') do |addr_validate|
            addr_validate << XmlNode.new('Address') do |addr|
              addr << XmlNode.new('StreetLines', location.address1)        
              addr << XmlNode.new('City', location.city)
              addr << XmlNode.new('StateOrProvinceCode', location.state)
              addr << XmlNode.new('PostalCode', location.postal_code)
              addr << XmlNode.new('CountryCode', location.country)        
            end
          end
        end
        xml_request.to_s
      end
      
      def parse_rate_response(origin, destination, packages, response, options)
        rate_estimates = []
        success, message = nil
        
        xml = REXML::Document.new(response)
        root_node = xml.elements['RateReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        root_node.elements.each('RateReplyDetails') do |rated_shipment|
          service_code = rated_shipment.get_text('ServiceType').to_s
          is_saturday_delivery = rated_shipment.get_text('AppliedOptions').to_s == 'SATURDAY_DELIVERY'
          service_type = is_saturday_delivery ? "#{service_code}_SATURDAY_DELIVERY" : service_code
          
          transit_time = rated_shipment.get_text('TransitTime').to_s if service_code == "FEDEX_GROUND"
          max_transit_time = rated_shipment.get_text('MaximumTransitTime').to_s if service_code == "FEDEX_GROUND"

          delivery_timestamp = rated_shipment.get_text('DeliveryTimestamp').to_s

          delivery_range = delivery_range_from(transit_time, max_transit_time, delivery_timestamp, options)

          currency = handle_incorrect_currency_codes(rated_shipment.get_text('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Currency').to_s)
          rate_estimates << RateEstimate.new(origin, destination, @@name,
                              self.class.service_name_for_code(service_type),
                              :service_code => service_code,
                              :total_price => rated_shipment.get_text('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Amount').to_s.to_f,
                              :currency => currency,
                              :packages => packages,
                              :delivery_range => delivery_range)
        end
		
        if rate_estimates.empty?
          success = false
          message = "No shipping rates could be found for the destination address" if message.blank?
        end

        RateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :request => last_request, :log_xml => options[:log_xml])
      end

      def delivery_range_from(transit_time, max_transit_time, delivery_timestamp, options)
        delivery_range = [delivery_timestamp, delivery_timestamp]
        
        #if there's no delivery timestamp but we do have a transit time, use it
        if delivery_timestamp.blank? && transit_time.present?
          transit_range  = parse_transit_times([transit_time,max_transit_time.presence || transit_time])
          delivery_range = transit_range.map{|days| business_days_from(ship_date(options[:turn_around_time]), days)}
        end

        delivery_range
      end

      def business_days_from(date, days)
        future_date = date
        count       = 0

        while count < days
          future_date += 1.day
          count += 1 if business_day?(future_date)
        end

        future_date
      end

      def business_day?(date)
        (1..5).include?(date.wday)
      end

      def parse_tracking_response(response, options)
        xml = REXML::Document.new(response)
        root_node = xml.elements['TrackReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          tracking_number, origin, destination, status, status_code, status_description, delivery_signature = nil
          shipment_events = []

          tracking_details = root_node.elements['TrackDetails']
          tracking_number = tracking_details.get_text('TrackingNumber').to_s

          status_code = tracking_details.get_text('StatusCode').to_s
          status_description = tracking_details.get_text('StatusDescription').to_s
          status = TRACKING_STATUS_CODES[status_code]

          if status_code == 'DL' && tracking_details.get_text('SignatureProofOfDeliveryAvailable').to_s == 'true'
            delivery_signature = tracking_details.get_text('DeliverySignatureName').to_s
          end

          origin_node = tracking_details.elements['OriginLocationAddress']

          if origin_node
            origin = Location.new(
                  :country =>     origin_node.get_text('CountryCode').to_s,
                  :province =>    origin_node.get_text('StateOrProvinceCode').to_s,
                  :city =>        origin_node.get_text('City').to_s
            )
          end

          destination_node = tracking_details.elements['DestinationAddress']

          if destination_node.nil?
            destination_node = tracking_details.elements['ActualDeliveryAddress']
          end

          destination = Location.new(
                :country =>     destination_node.get_text('CountryCode').to_s,
                :province =>    destination_node.get_text('StateOrProvinceCode').to_s,
                :city =>        destination_node.get_text('City').to_s
              )
          
          tracking_details.elements.each('Events') do |event|
            address  = event.elements['Address']

            city     = address.get_text('City').to_s
            state    = address.get_text('StateOrProvinceCode').to_s
            zip_code = address.get_text('PostalCode').to_s
            country  = address.get_text('CountryCode').to_s
            next if country.blank?
            
            location = Location.new(:city => city, :state => state, :postal_code => zip_code, :country => country)
            description = event.get_text('EventDescription').to_s

            time          = Time.parse("#{event.get_text('Timestamp').to_s}")
            zoneless_time = time.utc

            shipment_events << ShipmentEvent.new(description, zoneless_time, location)
          end
          shipment_events = shipment_events.sort_by(&:time)

        end
        
        TrackingResponse.new(success, message, Hash.from_xml(response),
          :carrier => @@name,
          :xml => response,
          :request => last_request,
          :status => status,
          :status_code => status_code,
          :status_description => status_description,
          :delivery_signature => delivery_signature,
          :shipment_events => shipment_events,
          :origin => origin,
          :destination => destination,
          :tracking_number => tracking_number
        )
      end

      def parse_shipping_response(response, options)
        xml = REXML::Document.new(response)
        root_node = xml.elements['ProcessShipmentReply']

        success = response_success?(xml)
        message = response_message(xml)
        if success
          # Define a few main sections of the XML response
          rate_type = root_node.elements['CompletedShipmentDetail/ShipmentRating/ActualRateType'].text
          shipment_details = root_node.elements['CompletedShipmentDetail/ShipmentRating'].detect{ |i| i.elements['RateType'] && i.elements['RateType'].text == rate_type }
          package_details = root_node.elements['CompletedShipmentDetail/CompletedPackageDetails']
          shipping_id = root_node.get_text('JobId').to_s

          # Pull in the information for the package itself
          tracking_number = package_details.get_text('TrackingIds/TrackingNumber').to_s
          service_option_charges = package_details.get_text('PackageRating/PackageRateDetails/NetCharge/Amount').to_s.to_f
          service_option_charges_currency = package_details.get_text('PackageRating/PackageRateDetails/NetCharge/Currency').to_s
          graphic_image = package_details.get_text('Label/Parts/Image').to_s

          shipment_charges = shipment_details.get_text('TotalNetCharge/Amount').to_s.to_f
          currency_code = shipment_details.get_text('TotalNetCharge/Currency').to_s
          billing_weight = shipment_details.get_text('TotalBillingWeight/Value').to_s.to_f
          weight_unit = shipment_details.get_text('TotalBillingWeight/Units').to_s

          shipped_package = options[:package]

          package = Package.new(shipped_package.ounces, [], {
            :tracking_number => tracking_number,
            :service_option_charges => service_option_charges,
            :service_option_charges_currency => service_option_charges_currency
          })

          # Hash.from_xml(response).values.first

          ShippingResponse.new(success, message, Hash.from_xml(response), {
            :carrier => @@name,
            :test => test_mode?,
            :test => options[:test],
            :xml => response,
            :request => last_request,
            :label => graphic_image,
            :shipping_id => shipping_id,
            :tracking_number => tracking_number,
            :shipment_charges => shipment_charges,
            :currency_code => currency_code,
            :billing_weight => billing_weight,
            :weight_unit => weight_unit,
            :package => package
          })
        else
          ShippingResponse.new(success, message, Hash.from_xml(response), {
            :xml => response,
            :request => last_request,
            :test => test_mode?
          })
        end
      end

      def parse_validation_response(response, options)
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)
        root_node = xml.elements['AddressValidationReply']
        if success
          result = root_node.elements['AddressResults/ProposedAddressDetails']
          address = {
            street: result.get_text('Address/StreetLines'),
            city: result.get_text('Address/City'),
            state: result.get_text('Address/StateOrProvinceCode'),
            postal_code: result.get_text('Address/PostalCode'),
            country: result.get_text('Address/CountryCode'),
            residential: (result.get_text('ResidentialStatus') != 'BUSINESS')
          }
          score = result.get_text('Score').to_s.to_i
          changes = result.each_element('Changes'){}.map(&:text)
          ValidationResponse.new(success, message, Hash.from_xml(response), {
            :xml => response,
            :request => last_request,
            :test => test_mode?,
            :address => address,
            :score => score,
            :changes => changes
          })
        else
          ValidationResponse.new(success, message, Hash.from_xml(response), {
            :xml => response,
            :request => last_request,
            :test => test_mode?
          })
        end
      end

      def ship_timestamp(delay_in_hours)
        delay_in_hours ||= 0
        Time.now + delay_in_hours.hours
      end

      def ship_date(delay_in_hours)
        delay_in_hours ||= 0
        (Time.now + delay_in_hours.hours).to_date
      end

      def response_status_node(document)
        document.elements['/*/Notifications/']
      end
      
      def response_success?(document)
        %w{SUCCESS WARNING NOTE}.include? response_status_node(document).get_text('Severity').to_s
      end
      
      def response_message(document)
        response_node = response_status_node(document)
        "#{response_status_node(document).get_text('Severity')} - #{response_node.get_text('Code')}: #{response_node.get_text('Message')}"
      end
      
      def commit(request, test = false)
        ssl_post(test ? TEST_URL : LIVE_URL, request.gsub("\n",''))        
      end
      
      def handle_incorrect_currency_codes(currency)
        case currency
        when /UKL/i then 'GBP'
        when /SID/i then 'SGD'
        else currency
        end
      end

      def remove_version_prefix(xml)
        if xml =~ /xmlns:v[0-9]/
          xml.gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        else
          xml
        end
      end

      def parse_transit_times(times)
        results = []
        times.each do |day_count|
          days = TransitTimes.index(day_count.to_s.chomp)
          results << days.to_i
        end
        results
      end
    end
  end
end
