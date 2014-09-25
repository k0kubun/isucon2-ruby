template "/tmp/isucon2.sql" do
  action :create
  source "../db/isucon2.sql"
  notifies :run, "execute[cat /tmp/isucon2.sql | mysql -uroot]"
  notifies :run, "execute[cat /tmp/initial_data.sql | mysql -uroot]"
end

template "/tmp/initial_data.sql" do
  action :create
  source "../db/initial_data.sql"
end

execute "cat /tmp/isucon2.sql | mysql -uroot" do
  action :nothing
end

execute "cat /tmp/initial_data.sql | mysql -uroot" do
  action :nothing
end
