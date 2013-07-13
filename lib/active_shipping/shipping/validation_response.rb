module ActiveMerchant #:nodoc:
  module Shipping
    
    class ValidationResponse < Response
      attr_reader :score # string
      attr_reader :address # string
      attr_reader :changes # string
      
      def initialize(success, message, params = {}, options = {})
        @score = options[:score]
        @address = options[:address]
        @changes = options[:changes]
        super
      end
    end
    
  end
end