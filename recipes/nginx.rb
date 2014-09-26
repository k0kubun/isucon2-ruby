package "nginx" do
  action :install
end

execute "service nginx restart" do
  action :nothing
end

template "/etc/nginx/nginx.conf" do
  action :create
  source "../config/nginx.conf.erb"
  notifies :run, "execute[service nginx restart]"
end

service "nginx" do
  action [:enable, :start]
end
