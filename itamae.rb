template "/etc/supervisord.conf" do
  action :create
  source "config/supervisord.conf.erb"
end
