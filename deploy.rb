include_recipe "./recipes/initialize.rb"

include_recipe "./recipes/development.rb"
include_recipe "./recipes/db.rb"
include_recipe "./recipes/app.rb"
include_recipe "./recipes/bench.rb"
include_recipe "./recipes/supervisord.rb"
include_recipe "./recipes/nginx.rb"
