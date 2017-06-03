require 'sinatra'
require 'net/http'
require 'json'
require 'digest'
require 'rqrcode'
require 'date'
require 'aws-sdk'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

set :root, File.dirname(__FILE__)
set :price, 30
set :payment_address, "NBCR2G-JL7VJF-3FKVI6-6SMZCG-4YBC6H-3BM2A6-LLTM"
set :nem_node, URI("http://85.25.36.97:7890")

get '/' do
  xem_price_btc = Net::HTTP.get_response(URI("https://bittrex.com/api/v1.1/public/getticker?market=btc-xem"))
  if xem_price_btc.kind_of? Net::HTTPSuccess
    @xem_price_satoshis = (JSON.parse(xem_price_btc.body)['result']['Last'] * 10**8).to_i
  else
    @xem_price_satoshis = 8500
  end

  xbt_price_usd = Net::HTTP.get_response(URI("https://api.kraken.com/0/public/Ticker?pair=XXBTZUSD"))
  if xbt_price_usd.kind_of? Net::HTTPSuccess
    @xbt_price_last = JSON.parse(xbt_price_usd.body)['result']['XXBTZUSD']['c'][0].to_f
  else
    @xbt_price_last = 2200.00
  end

  @xem_price_usd = (@xbt_price_last * 10**-8) * @xem_price_satoshis

  erb :index
end

post '/' do
  @xem_price_usd = params[:xem_price_usd].to_f
  @usd_price = @xem_price_usd * settings.price

  @id_hash = Digest::SHA256.hexdigest(params[:user_email])[0,31] # Truncate the hash for cheaper tx fee.
  payment_data = {
    v: 2,
    type: 2,
    data: {
      addr: settings.payment_address.gsub("-", ""),
      amount: settings.price * 10**6,
      msg: @id_hash
    }
  }

  qrcode = RQRCode::QRCode.new(payment_data.to_json)
  @qr = qrcode.as_svg(
  offset: 0,
  color: '000',
  shape_rendering: 'crispEdges',
  module_size: 4)

  erb :payment
end

post '/download' do
  node = settings.nem_node
  node_status = Net::HTTP.get(URI("#{node}/node/info"))
  @node_name = JSON.parse(node_status)['identity']['name']

  transfers = Net::HTTP.get(URI("#{node}/account/transfers/incoming?address=#{settings.payment_address.gsub("-", "")}"))
  data = JSON.parse(transfers)['data']

  @id_hash = params[:id_hash]
  @encoded_message = @id_hash.unpack('H*')
  @search = data.find_all { |i| i['transaction']['message']['payload'] == @encoded_message[0] }
  @tx_list = Array.new
  @paid = Array.new
  @search.count > 1 ? @transaction = "transactions" : @transaction = "transaction"

  if @search.empty?
    erb :tx_not_found
  else
    @search.each_with_index do |tx, index|
      @tx_list[index] = tx['meta']['hash']['data']
      @paid << tx['transaction']['amount']
    end
    @paid = @paid.sum.to_f * 10**-6
    @difference = settings.price - @paid
    if @paid < settings.price
      erb :low_payment
    else
      @download_link = Digest::SHA256.hexdigest(DateTime.now.strftime('%s'))
      erb :download
    end
  end
end

post "/:download_link" do
  signer = Aws::S3::Presigner.new
  url = signer.presigned_url(:get_object, bucket: "nemp3", key: "Ochre - Beyond the Outer Loop.zip", expires_in: 300)
  redirect url
end

not_found do
  erb :'404'
end
