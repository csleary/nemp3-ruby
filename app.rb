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

  payment_address = "TCQFU2U2UR27EYLADA6FNE6KY7ONFM7YH7ZYREBS"
  transfers = Net::HTTP.get(URI("#{node}/account/transfers/incoming?address=#{payment_address}"))
  data = JSON.parse(transfers)['data']

  @hash = params[:hash]
  @encoded_message = @hash.unpack('H*')
  @search = data.find_all { |i| i['transaction']['message']['payload'] == @encoded_message[0] }
  @tx_list = Array.new
  @paid = Array.new

  if @search.empty?
    @tx_message = <<-EOM
    <p class="alert alert-danger" role="alert">
      Error! Could not find your transaction. Are you sure it's confirmed?
    </p>
    <p>
      You can either hit the back button to see the payment info again, or <a href="/">start over</a>.
    </p>
    EOM
    @download_button = nil
  else
    @search.each_with_index do |i, index|
      @tx_list[index] = i['meta']['hash']['data']
      @paid << i['transaction']['amount']
    end
    @paid = @paid.sum.to_f / 1000000
    @difference = settings.price - @paid
    if @paid < settings.price
      @tx_message = <<-EOM
      <p class="alert alert-warning" role="alert">
        We successfully found your transaction(s), but unfortunately it seems you haven't quite met the payment price of #{settings.price} XEM. You've currently paid <strong>#{sprintf "%.2f", @paid} XEM</strong> to date, so please send an extra <strong>#{sprintf "%.2f", @difference} XEM</strong> using the same address, and return for your download. Thanks!
      </p>
      <p>
        Transaction(s) found:
      </p>
      EOM
    else
      @tx_message = <<-EOM
      <p class="alert alert-success" role="alert">
        Success! Transaction(s) found (<strong>#{sprintf "%.2f", @paid} XEM</strong> paid to date):
      </p>
      EOM
      @download_link = Digest::SHA256.hexdigest DateTime.now.strftime('%s')
      @download_button = <<-EOM
      <p>
        <form class="" action="/#{@download_link}" method="post">
        <input type="hidden" name="dl_link" value="#{@download_link}">
        <button type="submit" class="btn btn-outline-success btn-lg btn-block">Download Album</button>
        </form>
      </p>
      EOM
    end
  end

  erb :download
end

post "/:download_link" do
  send_file File.join(settings.public_folder, 'b990f5bcf64e5c04d25112b1.zip'),
  :type => :zip,
  :filename => 'hi.zip'
end
