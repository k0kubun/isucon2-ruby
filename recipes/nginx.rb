template "/etc/nginx/nginx.conf" do
  action :create
  source "../config/nginx.conf.erb"
end
