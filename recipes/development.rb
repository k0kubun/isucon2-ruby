template "/home/isu-user/.bashrc" do
  action :create
  source "../configs/.bashrc.erb"
end

