require 'spec_helper'
require_relative '../lib/active_shipping/shipping/carriers/dhl.rb'

describe ActiveMerchant::Shipping::DHL do

  describe 'DHL API Calls' do
    include WebMock::API
    let (:username) {'username'}
    let (:password) {'password'}
    let (:client_id) {1}
    let (:tracking_number) {'1234567'}
    let (:dhl) {ActiveMerchant::Shipping::DHL.new(username:username, password:password, client_id:client_id)}

    before do
    end
    describe '#retrieve_token' do
      let (:body) {''}
      let (:status) {400}

      before do
        stub_request(:get, "https://api.dhlglobalmail.com/v1/auth/access_token.json?username=#{username}&password=#{password}").
            to_return(status:status, body:body)
      end

      context 'valid credentials' do
        let(:body) {'{"meta":{"timestamp":"2016-01-29T20:00:55-05:00","code":200},"data":{"access_token":"goodtoken","expires_in":86400,"scope":"return_label,status,encode,closeout,sortcode,label,manifest_session,accounts,locations,events,products,mailitems"}}'}
        let(:status) {200}
        let(:token) {dhl.retrieve_token}

        it { expect(token).to eql('goodtoken')}

      end

      context 'invalid credentials' do
        let(:body) {'{"meta":{"error":[{"error_message":"Username and\/or password provided are invalid.","error_type":"INVALID_LOGIN"}],"timestamp":"2016-01-29T20:10:18-05:00","code":400}}'}
        let(:status) {400}
        before do
          @message = ''
          begin
            dhl.retrieve_token
          rescue ActiveMerchant::Shipping::DHL::APIError => e
            @message = e.message
          end
        end

        it {expect(@message).to eql('DHL: Unable to authenticate:Username and/or password provided are invalid.')}

      end
    end

    describe '#call_tracking' do

      let (:body) {''}
      let (:status) {''}
      let (:tracking_number) {'1234567'}
      let (:token) {'injected-token'}
      let (:response) {dhl.find_tracking_info(tracking_number)}

      before do
        dhl.instance_variable_set(:@private_token, token)
        url = dhl.get_tracking_url(tracking_number, token)
        stub_request(:get, url).
            to_return(status:status, body:body)
      end

      context 'valid credentials' do
        context 'tracking number found' do
          let (:body) {'{"meta":{"links":{"prev":"","next":""},"total":1,"limit":1,"offset":0,"timestamp":"2014-04-10T23:08:56-04:00","code":200},"data":{"mailItems":[{"recipient":{"address2":"","signedForName":"signedforname"},"events":[{"location":"Pulaski,NY,US","time":"11:53:00","postalCode":"13142","description":"Delivered","country":"US","date":"2014-03-26","id":600,"timeZone":"ET"},{"location":"Pulaski,NY,US","time":"08:20:00","postalCode":"13142","description":"OutforDelivery","country":"US","date":"2014-03-26","id":598,"timeZone":"ET"},{"location":"Pulaski,NY,US","time":"14:02:00","postalCode":"13142","description":"ArrivalatPostOffice","country":"US","date":"2014-03-25","id":520,"timeZone":"ET"},{"location":"Hebron,KY,US","time":"15:56:17","postalCode":"41048","description":"DepartureDHLeCommerceFacility","country":"US","date":"2014-03-22","id":300,"timeZone":"ET"},{"location":"Hebron,KY,US","time":"12:10:05","postalCode":"41048","description":"Processed","country":"US","date":"2014-03-22","id":220,"timeZone":"ET"}],"pickup":{"account":5100000,"country":"country"},"mail":{"consignmentNoteNumber":"9999999999","productCategory":"Priority","mailIdentifier":"9999999999"}}]}}'}
          let (:status) {200}

          it {expect(response.shipment_events.count).to be > 0}
          it {expect(response.shipment_events.last.name).to eql('Delivered')}
        end

        context 'tracking number not found' do
          let (:body) {'{"meta":{"error":[{"error_message":"No Results for your query","error_type":"NO_DATA"}],"timestamp":"2016-02-01T18:30:52-05:00","code":400}}'}
          let (:status) {400}

          it {expect(response.shipment_events.count).to eql(0)}
          it {expect(response.message).to eql('No Results for your query')}

        end
      end

      context 'invalid credentials' do
        let(:body) {'{"meta":{"error":[{"error_message":"Access Token provided was invalid","error_type":"INVALID_TOKEN"}],"timestamp":"2016-02-01T19:20:04-05:00","code":400}}'}
        let(:status) {400}
        before do
          dhl.instance_variable_set(:@retries, 1)
          @message = ''
          begin
            dhl.find_tracking_info(tracking_number)
          rescue ActiveMerchant::Shipping::DHL::APIError => e
            @message = e.message
          end
        end

        it {expect(@message).to eql('DHL: Max retries of authentication exceeded, could not get access token')}
      end
    end
  end
end