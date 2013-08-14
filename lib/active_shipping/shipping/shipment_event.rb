module ActiveMerchant #:nodoc:
  module Shipping
      
    class ShipmentEvent
      attr_reader :name, :time, :location, :message
      attr_accessor :data

      def initialize(name, time, location, message=nil)
        @name, @time, @location, @message = name, time, location, message
      end
      
    end
    
  end
end