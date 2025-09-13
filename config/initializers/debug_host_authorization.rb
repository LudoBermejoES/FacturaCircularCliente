if false # Rails.env.test? - DISABLED completely for clean output
  puts "=" * 80
  puts "🔍 DEBUG_HOST_AUTHORIZATION: Initializer loaded in #{Rails.env} environment"
  puts "🔍 Initial hosts: #{Rails.application.config.hosts.inspect}"
  puts "🔍 Ruby version: #{RUBY_VERSION}"
  puts "🔍 Rails version: #{Rails.version}"
  puts "🔍 Process ID: #{Process.pid}"
  puts "🔍 Current time: #{Time.current}"
  puts "=" * 80
  
  # Add detailed logging for host authorization
  Rails.application.config.after_initialize do
    puts "\n" + "🔍" * 40
    puts "🔍 AFTER INITIALIZE - FINAL CONFIGURATION"
    puts "🔍" * 40
    puts "🔍 Final hosts: #{Rails.application.config.hosts.inspect}"
    puts "🔍 Middleware count: #{Rails.application.middleware.count}"
    
    # Log middleware stack
    puts "🔍 Middleware stack:"
    Rails.application.middleware.each_with_index do |middleware, index|
      marker = middleware.klass.to_s.include?('HostAuthorization') ? '👀' : '  '
      puts "#{marker} #{index.to_s.rjust(2)}: #{middleware.klass}"
    end
    
    puts "🔍" * 40 + "\n"
    
    # Monkey patch ActionDispatch::HostAuthorization for detailed logging
    if defined?(ActionDispatch::HostAuthorization)
      ActionDispatch::HostAuthorization.prepend(Module.new do
        def call(env)
          host_header = env["HTTP_HOST"]
          server_name = env["SERVER_NAME"]
          server_port = env["SERVER_PORT"]
          request_uri = env["REQUEST_URI"]
          
          puts "\n🚨 HOST AUTHORIZATION CHECK:"
          puts "   HTTP_HOST: '#{host_header}'"
          puts "   SERVER_NAME: '#{server_name}'"
          puts "   SERVER_PORT: '#{server_port}'"
          puts "   REQUEST_URI: '#{request_uri}'"
          puts "   Full host string: '#{host_header || server_name}'"
          puts "   Configured hosts: #{@permissions.inspect}"
          
          result = super(env)
          
          if result[0] == 403
            puts "   ❌ RESULT: HOST BLOCKED (403)"
            puts "   Response headers: #{result[1].inspect}"
            puts "   Response body preview: #{result[2].respond_to?(:each) ? result[2].first[0..200] : 'Not readable'}"
          else
            puts "   ✅ RESULT: HOST ALLOWED (#{result[0]})"
          end
          puts "🚨 END HOST AUTHORIZATION CHECK\n"
          
          result
        end
      end)
      
      puts "✅ HostAuthorization middleware patched for detailed logging"
    else
      puts "⚠️ ActionDispatch::HostAuthorization not found"
    end
  end
end