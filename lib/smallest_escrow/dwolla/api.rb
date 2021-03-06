module SmallestEscrow
  module Dwolla
    class API
      def initialize(config)
        @config = config
        @rest = Faraday.new(:url => 'https://www.dwolla.com') do |builder|
                  builder.request  :json
                  builder.adapter  :net_http
                end
        @accountapi = "https://www.dwolla.com/oauth/rest/accountapi/"
        @oauth_consumer = OAuth::Consumer.new(@config['key'], 
                                              @config['secret'], 
                                              :site => "https://www.dwolla.com",
                                              :request_token_path => "/oauth/oauth.ashx",
                                              :authorize_path => "/oauth/oauth.ashx",
                                              :access_token_path => "/oauth/oauth.ashx" )
      end

      # Offsite Payments API

      # Redirect path comes back with extra fields:
      # checkoutid=b32683b5-9597-42a8-a8c8-741633e07d2f&transaction=257871&postback=failure&orderid=1.1771473012599911E+38
      # Callback is a POST with JSON in the body: '{"Amount":1.0000,"OrderId":null,"Status":"Completed","TransactionId":257892,"TestMode":false}'
      def checkout(deal)
        data = { :Key => @config['key'],
                 :Secret => @config['secret'],
                 :OrderId => deal.uuid,
                 :Callback => @config['host']+"/dwolla/payment",
                 :Redirect => @config['host']+"/#{deal.uuid}",
                 :PurchaseOrder => {
                        :DestinationId => DWOLLA.receiving_address,
                             :Discount => 0,
                           :OrderItems => [:Name => "Bitcoin Escrow #{deal.btc}BTC for $#{deal.usd}USD deal ##{deal.uuid}",
                                           :Price => deal.usd,
                                           :Quantity => 1],
                             :Shipping => 0,
                                  :Tax => 0,
                                :Total => deal.usd }}
        result = @rest.post('/payment/request', data)
        JSON.parse(result.body)
      end

      def checkout_url(id)
        "https://www.dwolla.com/payment/checkout/#{id}"
      end

      # REST API
      def request_token(scope = 'AccountAPI:transactions|AccountAPI:send')
        @oauth_consumer.get_request_token({:oauth_callback => @config['host']+"/dwolla/oauth"},
                                          {:scope => scope})
        # One time setup: admin visits @request_token.authorize_url to enable app with escrow dwolla account
      end

      def access_token(cred)
        OAuth::AccessToken.new(@oauth_consumer, cred.token, cred.secret)
      end

    end
  end
end