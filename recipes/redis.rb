# MEMO:
# execute("rpm -ivh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm")
# execute("yum --enablerepo=epel -y install redis")

package "redis" do
  options "--enablerepo=epel -y"
  action :install
end

service "redis" do
  action [:enable, :start]
end
