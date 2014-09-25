git "/home/isu-user/isucon2-ruby" do
  repository "git@github.com:k0kubun/isucon2-ruby"
  user "isu-user"
  notifies :run, "execute[supervisorctl restart isucon_ruby]"
end

execute "supervisorctl restart isucon_ruby" do
  action :nothing
end

execute "cd /home/isu-user/isucon2-ruby/app; /home/isu-user/isucon2-ruby/config/env.sh bundle install"
