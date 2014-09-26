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
  set :slim, pretty: true, layout: true

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
        host: config['host'],
        port: config['port'],
        username: config['username'],
        password: config['password'],
        database: config['dbname'],
        reconnect: true,
      )
    end

    def dict(arg)
      if defined?(@dict)
        @dict[arg.to_i - 1]
      else
        @dict = []
        10.times do |idx|
          variation = [
            {id: 1, name: 'アリーナ席'},
            {id: 2, name: 'スタンド席'},
            {id: 3, name: 'アリーナ席'},
            {id: 4, name: 'スタンド席'},
            {id: 5, name: 'アリーナ席'},
            {id: 6, name: 'スタンド席'},
            {id: 7, name: 'アリーナ席'},
            {id: 8, name: 'スタンド席'},
            {id: 9, name: 'アリーナ席'},
            {id: 10, name: 'スタンド席'},
          ][idx]
          if variation[:id] < 3
            ticket = {id: 1, name: '西武ドームライブ'}
          elsif variation[:id] < 5
            ticket = {id: 2, name: '東京ドームライブ'}
          elsif variation[:id] < 7
            ticket = {id: 3, name: 'さいたまスーパーアリーナライブ'}
          elsif variation[:id] < 9
            ticket = {id: 4, name: '横浜アリーナライブ'}
          elsif variation[:id] < 11
            ticket = {id: 5, name: '西武ドームライブ'}
          end

          if ticket[:id] < 3
            artist = {id: 1, name: 'NHN48'}
          else
            artist = {id: 2, name: 'はだいろクローバーZ'}
          end

          @dict << {
            v_name: variation[:name],
            t_name: ticket[:name],
            a_name: artist[:name],
          }
        end

        return @dict[arg.to_i - 1]
      end
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

    def update_recent_sold
      mysql = connection

      recent_sold = mysql.query('SELECT order_id, seat_id, variation_id FROM stock, (SELECT id FROM stock WHERE order_id IS NOT NULL ORDER BY order_id DESC LIMIT 10) AS t WHERE t.id = stock.id').to_a
      return [] if recent_sold.size == 0

      recent_sold.each do |stock|
        dict(stock['variation_id']).each do |key, value|
          stock[key] = value
        end
      end

      values = recent_sold.map { |data|
        %Q{('#{data["seat_id"]}',#{data["order_id"] ? data["order_id"] : "NULL" },'#{data[:a_name]}','#{data[:t_name]}','#{data[:v_name]}')}
      }.join(",")
      mysql.query(<<-SQL)
        INSERT INTO recent_sold (seat_id, order_id, a_name, t_name, v_name)
        VALUES #{values}
        ON DUPLICATE KEY UPDATE
          recent_sold.seat_id=VALUES(seat_id),
          recent_sold.order_id=VALUES(order_id),
          recent_sold.a_name=VALUES(a_name),
          recent_sold.t_name=VALUES(t_name),
          recent_sold.v_name=VALUES(v_name)
      SQL

      recent_sold
    end

    def purge_all_page_cache
      (1..2).each do |artistid|
        fragment_store.purge("render_artist_#{artistid}")
      end

      (1..5).each do |ticketid|
        fragment_store.purge("render_ticket_#{ticketid}")
      end
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
        slim :ticket, locals: {
          ticket: ticket,
          variations: variations,
        }
      end
    end

    def render_artist(artistid)
      key = "render_artist_#{artistid}"

      fragment_store.cache(key) do
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
        slim :artist, locals: {
          artist: artist,
          tickets: tickets,
        }
      end
    end
  end

  # main

  get '/' do
    mysql = connection
    artists = mysql.query("SELECT * FROM artist ORDER BY id")
    slim :index, locals: {
      artists: artists,
    }
  end

  get '/artist/:artistid' do
    render_artist(params[:artistid])
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
      update_recent_sold

      seat_id = mysql.query(
        "SELECT seat_id FROM stock WHERE order_id = #{ mysql.escape(order_id.to_s) } LIMIT 1",
      ).first['seat_id']
      mysql.query('COMMIT')

      ticketid = mysql.query("SELECT ticket_id FROM variation WHERE id = #{variation_id} LIMIT 1").first["ticket_id"]
      fragment_store.purge("render_ticket_#{ticketid}")

      artistid = mysql.query("SELECT artist_id FROM ticket WHERE id = #{ticketid} LIMIT 1").first["artist_id"]
      fragment_store.purge("render_artist_#{artistid}")

      slim :complete, locals: { seat_id: seat_id, member_id: params[:member_id] }
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
    mysql.query('delete from recent_sold')
    open(File.dirname(__FILE__) + '/../db/initial_data.sql') do |file|
      file.each do |line|
        next unless line.strip!.length > 0
        mysql.query(line)
      end
    end
    update_recent_sold
    purge_all_page_cache

    (1..5).each do |ticketid|
      fragment_store.purge("render_ticket_#{ticketid}")
    end

    redirect '/admin', 302
  end

  run! if app_file == $0
end
