template "/etc/supervisord.conf" do
  action :create
  source "../config/supervisord.conf.erb"
  notifies :run, "execute[service supervisord restart]"
end

execute "service supervisord restart" do
  action :nothing
end

service "supervisord" do
  action [:enable, :start]
end
