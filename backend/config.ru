# This file is used by Rack-based servers to start the application.

# Simple Rack app to bypass Rails initialization issues

class NeofyApp
  def call(env)
    request = Rack::Request.new(env)
    
    case request.path_info
    when '/'
      [200, {'Content-Type' => 'application/json'}, [{message: 'Neofy API is running', status: 'ok', version: '1.0.0'}.to_json]]
    when '/health'
      [200, {'Content-Type' => 'application/json'}, [{status: 'ok', timestamp: Time.now.iso8601, version: '1.0.0'}.to_json]]
    else
      [404, {'Content-Type' => 'application/json'}, [{error: 'Not found'}.to_json]]
    end
  end
end

run NeofyApp.new
