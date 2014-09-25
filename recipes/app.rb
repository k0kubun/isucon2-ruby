git "/home/isu-user/isucon2-ruby" do
  repository "https://github.com/k0kubun/isucon2-ruby"
  user "isu-user"
  notifies :run, "execute[supervisorctl restart isucon_ruby]"
end

template "/home/isu-user/isucon2-ruby/app/config/newrelic.yml" do
  action :create
  source "../app/config/newrelic.yml"
end

execute "supervisorctl restart isucon_ruby" do
  action :nothing
end

execute "cd /home/isu-user/isucon2-ruby/app; /home/isu-user/isucon2-ruby/config/env.sh bundle install"
