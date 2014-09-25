template "/home/isu-user/.bashrc" do
  action :create
  source "../config/.bashrc.erb"
end

