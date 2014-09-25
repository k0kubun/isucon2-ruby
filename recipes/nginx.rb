package "nginx" do
  action :install
end

template "/etc/nginx/nginx.conf" do
  action :create
  source "../configs/nginx.conf.erb"
end
