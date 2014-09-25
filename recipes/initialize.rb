init_commands = <<-EOS
  supervisorctl stop isucon_ruby
  supervisorctl stop benchmark
  service supervisord stop
  service httpd stop
  chkconfig httpd off
  touch /tmp/already_initialized
EOS

init_commands.each_line do |command|
  execute command do
    not_if "test -e /tmp/already_initialized"
  end
end
