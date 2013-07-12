# -*- coding: utf-8 -*-
module ActiveMerchant
  module Shipping
    class OnTrac < Carrier
      cattr_reader :name
      cattr_reader :label_type

      @@name = "On Trac"

      def requirements
        [:username, :password]
      end

      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        
        rate_request = build_rate_request(origin, destination, packages, options)
        
        response = commit(save_request(rate_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')

        parse_rate_response(origin, destination, packages, response, options)
      end
      
      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        
        tracking_request = build_tracking_request(tracking_number, options)

        response = commit(save_request(tracking_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        
        parse_tracking_response(response, options)
      end

      def create_shipment(origin, destination, package, options = {})
        options = @options.update(options)

        shipment_request = build_shipment_request(origin, destination, package, options)

        response = commit(save_request(shipment_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')

        parse_shipping_response(response, options.merge(package: package))
      end

      protected

      def build_shipment_request(origin, destination, package, options)
        
      end

      def build_rate_request(origin, destination, packages, options)
        
      end

      def build_tracking_request(tracking_number, options)
        
      end

      def parse_rate_response(origin, destination, packages, response, options)
        
      end

      def parse_tracking_response(response, options)
        
      end

      def parse_shipping_response(response, options)
        
      end
    end
  end
end