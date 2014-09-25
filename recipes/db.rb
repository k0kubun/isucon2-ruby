template "/tmp/isucon2.sql" do
  action :create
  source "../db/isucon2.sql"
  notifies :run, "execute[cat /tmp/isucon2.sql | mysql -uroot]"
end

execute "cat /tmp/isucon2.sql | mysql -uroot"
