def production?
  ENV["RACK_ENV"] == "production"
end

def development?
  !production?
end

require 'sinatra/base'
require 'slim'
require 'json'
require 'mysql2'
require "singleton"
require "redis"

if development?
  require "rack-lineprof"
  require "pry"
  require "sinatra/reloader"
end

class FragmentStore
  include Singleton

  def cache(key, &block)
    cached = redis.get(key)
    if cached
      Marshal.load(cached)
    else
      update(key, block.call)
    end
  end

  def update(key, value)
    redis.set(key, Marshal.dump(value))
    value
  end

  def purge(key)
    redis.del(key)
  end

  def increment(key)
    redis.incr(key)
  end

  def decrement(key)
    redis.decr(key)
  end

  private

  def redis
    @redis ||= Redis.new
  end
end

class Isucon2App < Sinatra::Base
  $stdout.sync = true
  set :slim, :pretty => true, :layout => true

  if development?
    use Rack::Lineprof, profile: "app\.rb|.*\.slim$"
  end

  configure do
    register Sinatra::Reloader unless production?
  end

  helpers do
    def fragment_store
      @fragment_store ||= FragmentStore.instance
    end

    def connection
      config = JSON.parse(IO.read(File.dirname(__FILE__) + "/../config/common.#{ ENV['ISUCON_ENV'] || 'local' }.json"))['database']
      Mysql2::Client.new(
        :host => config['host'],
        :port => config['port'],
        :username => config['username'],
        :password => config['password'],
        :database => config['dbname'],
        :reconnect => true,
      )
    end

    def recent_sold
      mysql = connection
      mysql.query(
        'SELECT stock.seat_id, variation.name AS v_name, ticket.name AS t_name, artist.name AS a_name FROM stock
           JOIN variation ON stock.variation_id = variation.id
           JOIN ticket ON variation.ticket_id = ticket.id
           JOIN artist ON ticket.artist_id = artist.id
         WHERE order_id IS NOT NULL
         ORDER BY order_id DESC LIMIT 10',
      )
    end

    def seat_map(stock)
      unless defined?(@seat_map_source)
        trs = stock.each_slice(64).map do |row_stock|
          tds = row_stock.map do |seat_id, order_id|
            "<td id='#{seat_id}' class='#{ order_id ? 'unavailable' : 'available' }'>"
          end
          "<tr>#{tds.join}</tr>"
        end
        @seat_map_source = %Q{"#{trs.join}"}
      end

      eval(@seat_map_source)
    end

    def update_ticket_fragment(ticketid)
      key = "render_ticket_#{ticketid}"

      fragment_store.purge(key)
      render_ticket(ticketid)
    end

    def render_ticket(ticketid)
      key = "render_ticket_#{ticketid}"

      fragment_store.cache(key) do
        mysql = connection
        ticket = mysql.query(
          "SELECT t.*, a.name AS artist_name FROM ticket t
           INNER JOIN artist a ON t.artist_id = a.id
           WHERE t.id = #{ ticketid } LIMIT 1",
        ).first
        variations = mysql.query(
          "SELECT id, name FROM variation WHERE ticket_id = #{ mysql.escape(ticket['id'].to_s) } ORDER BY id",
        )
        variations.each do |variation|
          variation["count"] = mysql.query(
            "SELECT COUNT(*) AS cnt FROM stock
             WHERE variation_id = #{ mysql.escape(variation['id'].to_s) } AND order_id IS NULL",
          ).first["cnt"]
          variation["stock"] = {}
          stocks = mysql.query( "SELECT seat_id, order_id FROM stock WHERE variation_id = #{ mysql.escape(variation['id'].to_s) }").to_a
          stocks.each do |stock|
            variation["stock"][stock["seat_id"]] = stock["order_id"]
          end
        end
        slim :ticket, :locals => {
          :ticket     => ticket,
          :variations => variations,
        }
      end
    end
  end

  # main

  get '/' do
    mysql = connection
    artists = mysql.query("SELECT * FROM artist ORDER BY id")
    slim :index, :locals => {
      :artists => artists,
    }
  end

  get '/artist/:artistid' do
    mysql = connection
    artist  = mysql.query(
      "SELECT id, name FROM artist WHERE id = #{ mysql.escape(params[:artistid]) } LIMIT 1",
    ).first
    tickets = mysql.query(
      "SELECT id, name FROM ticket WHERE artist_id = #{ mysql.escape(artist['id'].to_s) } ORDER BY id",
    )
    tickets.each do |ticket|
      ticket["count"] = mysql.query(
        "SELECT COUNT(*) AS cnt FROM variation
         INNER JOIN stock ON stock.variation_id = variation.id
         WHERE variation.ticket_id = #{ mysql.escape(ticket['id'].to_s) } AND stock.order_id IS NULL",
      ).first["cnt"]
    end
    slim :artist, :locals => {
      :artist  => artist,
      :tickets => tickets,
    }
  end

  get '/ticket/:ticketid' do
    render_ticket(params[:ticketid])
  end

  post '/buy' do
    mysql = connection
    mysql.query('BEGIN')
    mysql.query("INSERT INTO order_request (member_id) VALUES ('#{ mysql.escape(params[:member_id]) }')")
    order_id = mysql.last_id
    variation_id = params[:variation_id]
    mysql.query(
      "UPDATE stock SET order_id = #{ mysql.escape(order_id.to_s) }
       WHERE variation_id = #{ variation_id } AND order_id IS NULL
       ORDER BY RAND() LIMIT 1",
    )
    if mysql.affected_rows > 0
      seat_id = mysql.query(
        "SELECT seat_id FROM stock WHERE order_id = #{ mysql.escape(order_id.to_s) } LIMIT 1",
      ).first['seat_id']
      mysql.query('COMMIT')

      ticketid = mysql.query("SELECT ticket_id FROM variation WHERE id = #{variation_id} LIMIT 1").first["ticket_id"]
      update_ticket_fragment(ticketid)

      slim :complete, :locals => { :seat_id => seat_id, :member_id => params[:member_id] }
    else
      mysql.query('ROLLBACK')
      slim :soldout
    end
  end

  # admin

  get '/admin' do
    slim :admin
  end

  get '/admin/order.csv' do
    mysql = connection
    body  = ''
    orders = mysql.query(
      'SELECT order_request.*, stock.seat_id, stock.variation_id, stock.updated_at
       FROM order_request JOIN stock ON order_request.id = stock.order_id
       ORDER BY order_request.id ASC',
    )
    orders.each do |order|
      order['updated_at'] = order['updated_at'].strftime('%Y-%m-%d %X')
      body += order.values_at('id', 'member_id', 'seat_id', 'variation_id', 'updated_at').join(',')
      body += "\n"
    end
    [200, { 'Content-Type' => 'text/csv' }, body]
  end

  post '/admin' do
    mysql = connection
    open(File.dirname(__FILE__) + '/../db/initial_data.sql') do |file|
      file.each do |line|
        next unless line.strip!.length > 0
        mysql.query(line)
      end
    end

    (1..5).each do |ticketid|
      fragment_store.purge("render_ticket_#{ticketid}")
    end

    redirect '/admin', 302
  end

  run! if app_file == $0
end
