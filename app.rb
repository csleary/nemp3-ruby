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

get '/' do
  erb :index
end

post '/' do
  @hash = Digest::SHA256.hexdigest params[:user_email].to_s
  payment_address = "TCQFU2U2UR27EYLADA6FNE6KY7ONFM7YH7ZYREBS"
  payment_data = {
    v: 2,
    type: 2,
    data: {
      addr: payment_address,
      amount: 30000000, # i.e. 30 XEM.
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

  payment_address = "TCQFU2U2UR27EYLADA6FNE6KY7ONFM7YH7ZYREBS"
  transfers = Net::HTTP.get(URI("#{node}/account/transfers/incoming?address=#{payment_address}"))
  data = JSON.parse(transfers)['data']

  @hash = params[:hash]
  @encoded_message = @hash.unpack('H*') # Now to search 'data' for the hex message.
  @search = data.find_all { |i| i['transaction']['message']['payload'] == @encoded_message[0] }
  @tx_list = Array.new
  if @search.empty?
    @tx_message = <<-EOM
    <p class="alert alert-danger" role="alert">
      Error! Could not find your transaction. Are you sure it's confirmed?
    </p>
    <p>
      You can either hit the back button to see the payment info again, or <a href="/">start over</a>.
    </p>
    EOM
    @button = nil
  else
    @search.each_with_index do |i, index|
      @tx_list[index] = i['meta']['hash']['data']
    end
    @tx_message = <<-EOM
    <p class="alert alert-success" role="alert">
    Success! Transaction(s) found:
    </p>
    EOM
    @dl_link = Digest::SHA256.hexdigest DateTime.now.strftime('%s')
    @button = <<-EOM
    <p>
    <form class="" action="/#{@dl_link}" method="post">
    <input type="hidden" name="dl_link" value="#{@dl_link}">
    <button type="submit" class="btn btn-outline-success btn-lg btn-block">Download Album</button>
    </form>
    </p>
    EOM
  end

  erb :download
end

post "/:dl_link" do
  redirect '/album.zip'
end
