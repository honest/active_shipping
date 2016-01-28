module ActiveMerchant
  module Shipping
    class DHL < Carrier
      cattr_reader :name

      @@name = "DHL"

      URL = 'https://api.dhlglobalmail.com'

      def requirements
        [:username, :password]
      end

      def initialize(options = {})
        super options
        @base_header = {'Accept' => 'application/json', 'Content-Type' => 'application/json;charset=UTF-8'}
        @retries = 0
        @threshold = options[:threshold] || 1
      end


      def find_tracking_info(number)
        token = get_token
        url = "#{URL}/v1/mailitems/track.json?access_token=#{token}&client_id=#{@options[:client_id]}&number=#{number}"
        response = Response.new(ssl_get(url, headers=@base_header))
        puts response.json
        if response.invalid_token?
          clear_token
          raise ResponseError('Max retries of authentication exceeded, could not get access token') unless @retries < @threshold
          @retries += 1
          call_tracking(number)
        end
        @retries = 0
        parse_tracking_response(response)
      end

      def parse_tracking_response(response)
        success = response.ok?
        message = response.error_message
        shipment_events = []

        if success
          shipment_events = response.events.map(&:access_token)
        end

        TrackingResponse.new(success, message, response.data,
                             :carrier => @@name,
                             :status => response.status,
                             :shipment_events => shipment_events
        )
      end

      def parse_event(event)
        code = event['id']
        description = event['description']
        time = Time.strptime("#{event['time']} #{event['date']}", '%H:%M:%S %Y-%m-%d' )
        {:code => code, :description => description, :time => time}
      end

      private

      def clear_token
        @private_token = nil
      end

      def get_token
        @private_token ||= retrieve_token
      end

      def retrieve_token
        url = "#{@root}/v1/auth/access_token.json?username=#{@options[:username]}&password=#{@options[:password]}"
        response = Response.new(ssl_get(url, headers=@base_header))
        raise ResponseError('Unable to authenticate, got this message: ' + response.error_message) unless response.ok?
        response.data['access_token']
      end

      class Response
        attr_accessor :json
        attr_accessor :meta
        attr_accessor :data

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
          ok? && @error && @error.first['error_message']
        end

        def events
          @data['mailItems'].first['events']
        end
      end

    end
  end
end
