git "/home/isu-user/isucon2-ruby" do
  repository "git@github.com:k0kubun/isucon2-ruby"
  user "isu-user"
end

execute "cd /home/isu-user/isucon2-ruby/app; /home/isu-user/isucon2-ruby/config/env.sh bundle install"
