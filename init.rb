user_name = "isu-user"
home_dir  = "/home/#{user_name}"
pubkey    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDTBqmCx8FUX01dLomDUhE+El33VsKMpDF7aTj2p05NKrlUmIfLD0BKkVUP1yLlJpDZsz83oogjlH5XZl4q7AvH4PNCbIiUuXxDeJevo5hDpqDaaBSDiDU0WRF82sng1bDrLCjXVXsXQ/nQLS7PsWFyBIlunnRHSO91NnZwhxxJgp9K89a0tFpTn/koRuW6b8om++1UtoY8+rjIC11qtj9G1hj78rqeJmNtWdoJsIG5qcjNl/DikJBhTLenAOTwK1BzhHdo0doTdZzal+6koE9fZ/lv8DvAciJr8IDIdHd73XJKFlm7GcOZ3EO/1N9JUbNHDCd+dWFolTqWghxa9Dr"

ssh_dir = File.join(home_dir, ".ssh")
directory ssh_dir do
  owner user_name
  group user_name
  mode "0700"
end

file "#{ssh_dir}/authorized_keys" do
  owner user_name
  content pubkey
  mode "0600"
end
