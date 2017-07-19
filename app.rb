# frozen_string_literal: true

require 'aws-sdk'
require 'date'
require 'digest'
require 'json'
require 'net/http'
require 'rqrcode'
require 'sinatra'

set :root, File.dirname(__FILE__)
set :price, 40

# set :environment, :production

if settings.production?
  set :payment_address, 'NBCR2G-JL7VJF-3FKVI6-6SMZCG-4YBC6H-3BM2A6-LLTM'
  set :network_version, 2
  set :explorer, 'chain.nem.ninja'
elsif settings.development?
  set :payment_address, 'TCQFU2-U2UR27-EYLADA-6FNE6K-Y7ONFM-7YH7ZY-REBS'
  set :network_version, 1
  set :explorer, 'bob.nem.ninja:8765'
  set :nodes, [
    '104.128.226.60:7890',
    '23.228.67.85:7890',
    '192.3.61.243:7890',
    '188.68.50.161:7890',
    '150.95.145.157:7890'
  ]
end

get '/' do
  # Fetch current xem prices via exchange APIs.
  xem_price_btc = Net::HTTP.get_response(
    URI('https://bittrex.com/api/v1.1/public/getticker?market=btc-xem')
  )
  @xem_price_satoshis =
    begin
      (JSON.parse(xem_price_btc.body)['result']['Last'] * 10**8).to_i
    rescue
      '[not available]'
    end

  xbt_price_usd = Net::HTTP.get_response(
    URI('https://api.kraken.com/0/public/Ticker?pair=XXBTZUSD')
  )
  @xbt_price_last =
    begin
      JSON.parse(xbt_price_usd.body)['result']['XXBTZUSD']['c'][0].to_f
    rescue
      0
    end

  begin
    @xem_price_usd = (@xbt_price_last * 10**-8) * @xem_price_satoshis
    @usd_price = @xem_price_usd * settings.price
  rescue
    @xem_price_usd = 0
    @usd_price = 0
  end
  erb :index
end

post '/' do
  @usd_price = params[:usd_price]

  # Calculate customer ID hash and truncate it for cheaper tx fee.
  @id_hash = Digest::SHA256.hexdigest(params[:user_email] +
  ENV['NEMP3_SECRET'])[0, 31]
  payment_data = {
    v: settings.network_version,
    type: 2,
    data: {
      addr: settings.payment_address.delete('-'),
      amount: settings.price * 10**6,
      msg: @id_hash
    }
  }

  # Present QR code and payment information.
  qrcode = RQRCode::QRCode.new(payment_data.to_json)
  @qr = qrcode.as_svg(
    offset: 0,
    color: '000',
    shape_rendering: 'crispEdges',
    module_size: 4
  )

  erb :payment
end

post '/download' do
  # Connect to a node.
  node = ''
  @node_name = ''

  # Mainnet
  if settings.production?
    nodes = Net::HTTP.get(URI('https://supernodes.nem.io/nodes'))
    nodes_parsed = JSON.parse(nodes)['nodes']

    nodes_parsed.each do |selected_node|
      node_ip = selected_node['ip']
      nis_port = selected_node['nisPort']
      node = "#{node_ip}:#{nis_port}"
      begin
        node_status = ''
        Timeout.timeout(1) do
          node_status = Net::HTTP.get_response(
            URI("http://#{node}/heartbeat")
          )
        end
        next unless (node_status.is_a? Net::HTTPSuccess) &&
                    (JSON.parse(node_status.body)['message'] == 'ok')
        @node_name = selected_node['alias']
        break
      rescue
        next
      end
    end

  # Testnet
  elsif settings.development?
    settings.nodes.each do |selected_node|
      begin
        node_info = ''
        Timeout.timeout(1) do
          node_info = Net::HTTP.get_response(
            URI("http://#{selected_node}/node/info")
          )
        end
        next unless node_info.is_a? Net::HTTPSuccess
        node = selected_node
        @node_name = JSON.parse(node_info.body)['identity']['name']
        break
      rescue
        next
      end
    end
  end

  # Fetch transactions in groups of 25.
  parameters = ''
  data = []

  loop do
    transfers = Net::HTTP.get(
      URI("http://#{node}/account/transfers/incoming?address="\
      "#{settings.payment_address.delete('-')}#{parameters}")
    )
    latest_data = JSON.parse(transfers)['data']
    break if latest_data.empty?
    tx_id = latest_data.last['meta']['id']
    parameters = "&id=#{tx_id}"
    data.concat latest_data
  end

  # Search transactions for customer purchases.
  @id_hash = params[:id_hash]
  @encoded_message = @id_hash.unpack('H*')

  @search_results = data.find_all do |tx|
    if tx['transaction'].key?('otherTrans')
      tx['transaction']['otherTrans']['message']['payload'] ==
        @encoded_message[0]
    else
      tx['transaction']['message']['payload'] == @encoded_message[0]
    end
  end

  @transaction = @search_results.count > 1 ? 'transactions' : 'transaction'

  # Decide how to act depending on search results.
  @explorer = settings.explorer
  @tx_list = []
  @paid = []

  if @search_results.empty?
    erb :tx_not_found
  else
    @search_results.each_with_index do |tx, index|
      tx_hash = tx['meta']['hash']['data']

      if tx['transaction'].key?('otherTrans')
        path = 'multisig'
        @paid << tx['transaction']['otherTrans']['amount']
      else
        path = 'transfer'
        @paid << tx['transaction']['amount']
      end

      @tx_list[index] = {
        hash: tx_hash,
        path: path
      }
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

post '/download/:download_link' do
  if params[:download_link] == params[:dl_link]
    signer = Aws::S3::Presigner.new

    url =
      if settings.production?
        signer.presigned_url(
          :get_object,
          bucket: 'nemp3',
          key: 'Ochre - Beyond the Outer Loop.zip',
          expires_in: 300
        )
      elsif settings.development?
        signer.presigned_url(
          :get_object,
          bucket: 'nemp3',
          key: 'Empty.zip',
          expires_in: 300
        )
      end

    redirect url
  else
    not_found
  end
end

get '/harvesting-space' do
  @message = 'Hit the button to find supernodes with free slots.
  It will take a little while to query each node.'
  @harvesting_space_list = []
  erb :harvesting_space
end

post '/harvesting-space' do
  nodes = Net::HTTP.get(URI('https://supernodes.nem.io/nodes'))
  nodes_parsed = JSON.parse(nodes)['nodes']
  free_slots_list = []

  nodes_parsed.each do |selected_node|
    begin
      node_ip = selected_node['ip']
      nis_port = selected_node['nisPort']
      node = "#{node_ip}:#{nis_port}"

      harvesting_space_req = Net::HTTP.post_form(
        URI("http://#{node}/account/unlocked/info"), {}
      )
      harvesting_space_response = JSON.parse(harvesting_space_req.body)
      unlocked = harvesting_space_response['num-unlocked'].to_i
      maximum = harvesting_space_response['max-unlocked'].to_i
      free_slots = maximum - unlocked

      next unless free_slots.positive?
      vacancy = {
        id: selected_node['id'],
        name: selected_node['alias'],
        ip: node_ip,
        free_slots: free_slots
      }
      free_slots_list << vacancy
    rescue
      next
    end

    break if free_slots_list.count == 5
  end

  @message = 'There looks to be free slots on these supernodes (max. 5 shown):'
  @harvesting_space_list = free_slots_list
  erb :harvesting_space
end

not_found do
  erb :'404'
end
