module ActiveMerchant
  module Shipping
    class Carrier
      def initialize (options = {})
        @options = options
        @last_request = nil
      end
    end
    class ShipmentEvent
      attr_reader :name, :time, :location, :message
      attr_accessor :data

      def initialize(name, time, location, message=nil)
        @name, @time, @location, @message = name, time, location, message
      end

    end


    class Response

      attr_reader :params
      attr_reader :message
      attr_reader :test
      attr_reader :xml
      attr_reader :request

      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params
        @test = options[:test] || false
        @xml = options[:xml]
        @request = options[:request]
      end

      def success?
        @success ? true : false
      end

      def test?
        @test ? true : false
      end
    end

    class TrackingResponse < Response
      attr_reader :carrier # symbol
      attr_reader :carrier_name # string
      attr_reader :status # symbol
      attr_reader :status_code # string
      attr_reader :status_description #string
      attr_reader :scheduled_delivery_date # time
      attr_reader :delivery_signature #string
      attr_reader :tracking_number # string
      attr_reader :shipment_events # array of ShipmentEvents in chronological order
      attr_reader :origin, :destination

      def initialize(success, message, params = {}, options = {})
        @carrier = options[:carrier].to_sym
        @carrier_name = options[:carrier]
        @status = options[:status]
        @status_code = options[:status_code]
        @status_description = options[:status_description]
        @scheduled_delivery_date = options[:scheduled_delivery_date]
        @delivery_signature = options[:delivery_signature]
        @tracking_number = options[:tracking_number]
        @shipment_events = Array(options[:shipment_events])
        @origin, @destination = options[:origin], options[:destination]
        super
      end
    end
  end
end