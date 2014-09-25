template "/etc/supervisord.conf" do
  action :create
  source "../config/supervisord.conf.erb"
  notifies :run, "execute[sudo service supervisord restart]"
end

execute "sudo service supervisord restart" do
  action :nothing
end

service "supervisord" do
  action [:enable, :start]
end
