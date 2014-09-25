git "/home/isu-user/isucon2" do
  repository "https://github.com/tagomoris/isucon2"
  user "isu-user"
end

execute "cd /home/isu-user/isucon2/tools; /home/isu-user/isucon2-ruby/config/env.sh npm install"
execute "cd /home/isu-user/isucon2/tools/http_load_isucon2; /home/isu-user/isucon2-ruby/config/env.sh make"

template "/tmp/isumaster.sql" do
  action :create
  source "../db/isumaster.sql"
  notifies :run, "execute[cat /tmp/isumaster.sql | mysql -uroot]"
end

execute "cat /tmp/isumaster.sql | mysql -uroot" do
  action :nothing
end
