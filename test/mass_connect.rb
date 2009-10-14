require File.join(File.dirname(__FILE__), 'server_test_tools')
include ServerTestTools

begin
  pid = Process.fork do
    server = create_server do
      hostname    'localhost'
      port        6670
      log_types   [:info, :warning, :error, :debug]
      debug       true
    end
    server.thread.join
  end
  
  1.upto(100) do
    create_client 6670
  end
  
ensure
  Process.
  Process.wait(pid, 0)
  close_all
end