module ActiveMerchant
  module Shipping
    class Label
      attr_reader :tracking_number, :img_data, :url

      def initialize(tracking_number, img_data = nil, url = nil)
        @tracking_number = tracking_number
        @img_data = img_data
        @url = url
      end
    end
  end
end
