template "/etc/supervisord.conf" do
  action :create
  source "../config/supervisord.conf.erb"
  notifies :run, "execute[supervisorctl stop isucon_ruby]"
  notifies :run, "execute[service supervisord restart]"
end

execute "supervisorctl stop isucon_ruby" do
  action :nothing
end

execute "service supervisord restart" do
  action :nothing
end

service "supervisord" do
  action [:enable, :start]
end
