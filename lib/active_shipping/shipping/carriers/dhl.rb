# -*- coding: utf-8 -*-
module ActiveMerchant
  module Shipping
    class DHL < Carrier
      cattr_reader :name

      class APIError < StandardError
      end

      @@name = 'DHL'

      URL = 'https://api.dhlglobalmail.com'
      HEADER = {'Accept' => 'application/json', 'Content-Type' => 'application/json;charset=UTF-8'}

      def requirements
        [:username, :password, :client_id]
      end

      def initialize(options = {})
        super options
        @last_request_url = ''
        @retries = 0
        @threshold = options[:threshold] || 1
        @private_token = options[:override_token] if options.has_key? :override_token
      end

      def find_tracking_info(number)
        token = get_token
        url = get_tracking_url(number, token)
        response = call_api(url)
        if response.invalid_token?
          clear_token
          if @retries >= @threshold
            raise APIError, 'DHL: Max retries of authentication exceeded, could not get access token'
          end
          @retries += 1
          find_tracking_info(number)
        end
        @retries = 0
        parse_tracking_response(response)
      end

      def parse_tracking_response(response)
        success = response.ok?
        message = response.error_message
        shipment_events = []

        if success
          shipment_events = response.events.map{|e| parse_event(e) }
          shipment_events = shipment_events.sort_by{|se| se[:time]}
        end

        TrackingResponse.new(true, message, response.data || response.error.first,
                             :carrier => @@name,
                             :shipment_events => shipment_events,
                             :last_request => @last_request_url
        )
      end

      def parse_event(event)
        code = event['id']
        description = event['description']
        time = Time.strptime("#{event['time']} #{event['date']}", '%H:%M:%S %Y-%m-%d' )
        {:code => code, :description => description, :time => time}
      end

      def retrieve_token
        url = get_token_url
        response = call_api(url)
        raise APIError('DHL: Unable to authenticate, got this message: ' + response.error_message) if !response.ok?
        response.data['access_token']
      end

      def get_tracking_url(number, token)
        "#{URL}/v1/mailitems/track.json?access_token=#{token}&client_id=#{@options[:client_id]}&number=#{number}"
      end

      def get_token_url
        "#{URL}/v1/auth/access_token.json?username=#{@options[:username]}&password=#{@options[:password]}"
      end

      private

      def clear_token
        @private_token = nil
      end

      def get_token
        @private_token ||= retrieve_token
      end

      def call_api(url)
        @last_request_url = url
        response = nil
        begin
          response = DHLResponse.new(RestClient.get(url, HEADER))
        rescue RestClient::BadRequest => e
          #if we can't parse what the api returns just include the whole thing
          if /meta/.match(e.response)
            response = DHLResponse.new e.response
            return handle_error_response(response)
          else
            raise APIError, e.message
          end
        rescue RestClient::Exception => e
          raise APIError, "DHL: Error calling api #{e.message} : #{e.response}"
        end
        response
      end

      def handle_error_response(response)
        case response.error_type
          when 'INVALID_LOGIN'
            raise APIError, 'DHL: Unable to authenticate:' + response.error_message
          when 'NO_DATA'
            response
          when 'INVALID_TOKEN'
            response
          when 'VALIDATION_ERROR'
            raise APIError, 'DHL: Bad format of tracking number:' + response.error_message
          else
            raise APIError, 'DHL: Error calling Tracking API:' + response.error_message
        end
      end

      class DHLResponse
        attr_accessor :json
        attr_accessor :meta
        attr_accessor :data
        attr_accessor :status
        attr_accessor :error

        def initialize (raw_content)
          @json = JSON.parse(raw_content)
          @status = @json['meta']['code']
          @meta = @json['meta']
          @data = @json['data']
          @error = @meta['error']
        end

        def ok?
          @status == 200
        end

        def invalid_token?
          !ok? && @error && @error.any?{|e| e['error_type'] == 'INVALID_TOKEN'}
        end

        def error_message
          !ok? && @error && @error.first['error_message']
        end

        def error_type
          !ok? && @error && @error.first['error_type']
        end

        def events
          @data['mailItems'].first['events']
        end
      end

    end
  end
end
