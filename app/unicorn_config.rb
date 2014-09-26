worker_processes 4
preload_app true

listen "127.0.0.1:5000"

stderr_path 'log/unicorn.log'
stdout_path 'log/unicorn.log'
