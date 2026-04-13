#!/usr/bin/env ruby

require 'socket'
require 'json'

server = TCPServer.new('0.0.0.0', ENV.fetch('PORT', 3000).to_i)

puts "Neofy API server starting on port #{ENV.fetch('PORT', 3000)}..."

loop do
  client = server.accept
  
  request_line = client.gets
  method, path, _ = request_line.split(' ')
  
  # Read headers
  while line = client.gets
    break if line.strip.empty?
  end
  
  response = case path
  when '/'
    {
      message: 'Neofy API is running',
      status: 'ok',
      version: '1.0.0',
      server: 'Basic Ruby HTTP Server'
    }
  when '/health'
    {
      status: 'ok',
      timestamp: Time.now.iso8601,
      version: '1.0.0',
      server: 'Basic Ruby HTTP Server'
    }
  else
    {
      error: 'Not found',
      path: path
    }
  end
  
  status_code = path == '/' || path == '/health' ? 200 : 404
  
  client.puts "HTTP/1.1 #{status_code} OK"
  client.puts "Content-Type: application/json"
  client.puts "Content-Length: #{response.to_json.bytesize}"
  client.puts "Connection: close"
  client.puts ""
  client.puts response.to_json
  
  client.close
end
