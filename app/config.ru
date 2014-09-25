require './app'
require "dotenv"
require "newrelic_rpm"

if defined?(Unicorn)
  require 'unicorn/oob_gc'
  use Unicorn::OobGC, 1, %r{\A/}
end

Dotenv.load
run Isucon2App
