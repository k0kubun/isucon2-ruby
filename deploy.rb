include_recipe "./recipes/initialize.rb"

include_recipe "./recipes/development.rb"
include_recipe "./recipes/db.rb"
include_recipe "./recipes/app.rb"
include_recipe "./recipes/bench.rb"
include_recipe "./recipes/supervisord.rb"
include_recipe "./recipes/varnish.rb"
include_recipe "./recipes/nginx.rb"

execute "log deployment" do
  command "cd /home/isu-user/isucon2-ruby/app; RACK_ENV=production /home/isu-user/isucon2-ruby/config/env.sh newrelic deployment"
end
