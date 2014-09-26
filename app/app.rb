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

if development?
  require "rack-lineprof"
  require "pry"
  require "sinatra/reloader"
end

class FragmentStore
  include Singleton

  def cache(cache_name, key, &block)
    cached = store[cache_name][key]
    if cached
      cached
    else
      update_fragment(cache_name, key, block.call)
    end
  end

  def update_fragment(cache_name, key, value)
    store[cache_name][key] = value
  end

  private

  def store
    @@store ||= Hash.new { |h, k| h[k] = {} }
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

    # DO NOT USE DOUBLE QUOTE because it is used by query
    def td_by_stock(seat_id, order_id)
      "<td id='#{seat_id}' class='#{ order_id ? 'unavailable' : 'available' }'></td>"
    end

    def seat_map(stock)
      unless defined?(@seat_map_source)
        trs = stock.each_slice(64).map do |row_stock|
          "<tr>#{row_stock.map{ |seat_id, td| td }.join}</tr>"
        end
        @seat_map_source = %Q{"#{trs.join}"}
      end

      eval(@seat_map_source)
    end

    def seat_row(stock, row)
      @seat_row_source ||= '"' + ("00".."63").map{ |i| %Q{\#\{seat_cell(stock, row, '#{i}')\}} }.join + '"'
      eval(@seat_row_source)
    end

    def seat_cell(stock, row, col)
      key = "#{row}-#{col}"
      if stock[key]
        %Q{<td class="unavailable" id="#{key}"></td>}
      else
        %Q{<td class="available" id="#{key}"></td>}
      end
    end

    def variations
      @variations ||= fragment_store.cache("table_cache", "variations") do
        mysql.query("SELECT * FROM variation").to_a
      end
    end

    def artists
      @artists ||= fragment_store.cache("table_cache", "artists") do
        mysql.query("SELECT * FROM artist").to_a
      end
    end

    def tickets
      @tickets ||= fragment_store.cache("table_cache", "tickets") do
        mysql.query("SELECT * FROM ticket").to_a
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
    mysql = connection
    ticket = mysql.query(
      "SELECT t.*, a.name AS artist_name FROM ticket t
       INNER JOIN artist a ON t.artist_id = a.id
       WHERE t.id = #{ mysql.escape(params[:ticketid]) } LIMIT 1",
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
      mysql.query(
        "SELECT seat_id, td FROM stock
         WHERE variation_id = #{ mysql.escape(variation['id'].to_s) }",
      ).each do |stock|
        variation["stock"][stock["seat_id"]] = stock["td"]
      end
    end
    slim :ticket, :locals => {
      :ticket     => ticket,
      :variations => variations,
    }
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
      mysql.query(<<-SQL)
        UPDATE stock SET td = "#{td_by_stock(seat_id, true)}"
        WHERE variation_id = #{ variation_id } AND seat_id = '#{ seat_id }'
      SQL
      mysql.query('COMMIT')
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

    stock_count = mysql.query("SELECT COUNT(1) AS count FROM stock").first["count"]
    (1..stock_count).each_slice(5000) do |stock_ids|
      stocks = mysql.query(<<-SQL)
        SELECT id, variation_id, seat_id, order_id FROM stock WHERE id IN (#{stock_ids.join(',')})
      SQL

      values = stocks.map do |stock|
        %Q{(#{stock['variation_id']},"#{stock['seat_id']}","#{td_by_stock(stock['seat_id'], stock['order_id'])}")}
      end

      mysql.query(<<-SQL)
        INSERT INTO stock (variation_id, seat_id, td)
        VALUES #{values.join(',')}
        ON DUPLICATE KEY UPDATE
          stock.variation_id=VALUES(variation_id),
          stock.seat_id=VALUES(seat_id),
          stock.td=VALUES(td)
      SQL
    end
    redirect '/admin', 302
  end

  run! if app_file == $0
end
