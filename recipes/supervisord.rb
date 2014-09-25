template "/etc/supervisord.conf" do
  action :create
  source "../configs/supervisord.conf.erb"
end
