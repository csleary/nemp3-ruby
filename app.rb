require 'sinatra'
require 'net/http'
require 'json'
require 'digest'
require 'rqrcode'
require 'date'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

set :price, 30
set :payment_address, "TCQFU2U2UR27EYLADA6FNE6KY7ONFM7YH7ZYREBS"

get '/' do
  erb :index
end

post '/' do
  @hash = Digest::SHA256.hexdigest params[:user_email].to_s
  payment_data = {
    v: 2,
    type: 2,
    data: {
      addr: settings.payment_address,
      amount: settings.price * 1000000,
      msg: @hash
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
  node = "http://37.187.70.29:7890"
  node_status = Net::HTTP.get(URI("#{node}/node/info"))
  @node_name = JSON.parse(node_status)['identity']['name']

  transfers = Net::HTTP.get(URI("#{node}/account/transfers/incoming?address=#{settings.payment_address}"))
  data = JSON.parse(transfers)['data']

  @hash = params[:hash]
  @encoded_message = @hash.unpack('H*')
  @search = data.find_all { |i| i['transaction']['message']['payload'] == @encoded_message[0] }
  @tx_list = Array.new
  @paid = Array.new
  @search.count > 1 ? @transaction = "transactions" : @transaction = "transaction"

  if @search.empty?
    erb :not_found
  else
    @search.each_with_index do |i, index|
      @tx_list[index] = i['meta']['hash']['data']
      @paid << i['transaction']['amount']
    end
    @paid = @paid.sum.to_f / 1000000
    @difference = settings.price - @paid
    if @paid < settings.price
      erb :low_payment
    else
      @download_link = Digest::SHA256.hexdigest DateTime.now.strftime('%s')
      erb :download
    end
  end
end

post "/:download_link" do
  send_file File.join(settings.public_folder, 'b990f5bcf64e5c04d25112b1.zip'),
  :type => :zip,
  :filename => 'hi.zip'
end
