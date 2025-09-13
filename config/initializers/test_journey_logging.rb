if false # Rails.env.test? - DISABLED to avoid middleware conflicts
  # Add comprehensive logging for test requests to understand the full journey
  
  Rails.application.config.to_prepare do
    # Skip middleware insertion if already frozen
    unless Rails.application.middleware.frozen?
      # Log all incoming requests in test environment
      Rails.application.middleware.insert_after(
        ActionDispatch::HostAuthorization,
        Class.new do
        def initialize(app)
          @app = app
        end
        
        def call(env)
          request = ActionDispatch::Request.new(env)
          
          puts "\n🌐 INCOMING REQUEST:"
          puts "   Method: #{request.method}"
          puts "   Path: #{request.path}"
          puts "   Full URL: #{request.original_url rescue 'Not available'}"
          puts "   Host: #{request.host}"
          puts "   Port: #{request.port}"
          puts "   Remote IP: #{request.remote_ip}"
          puts "   User Agent: #{request.user_agent[0..100] rescue 'Not available'}"
          puts "   Content Type: #{request.content_type}"
          
          start_time = Time.current
          status, headers, response = @app.call(env)
          end_time = Time.current
          
          puts "🌐 REQUEST PROCESSED:"
          puts "   Status: #{status}"
          puts "   Duration: #{((end_time - start_time) * 1000).round(2)}ms"
          puts "   Response headers: #{headers.select { |k, v| k.downcase.include?('content') || k.downcase.include?('location') }}"
          
          if status >= 400
            puts "❌ ERROR RESPONSE:"
            if response.respond_to?(:each)
              body_preview = ""
              response.each { |chunk| body_preview += chunk[0..500]; break }
              puts "   Body preview: #{body_preview}"
            end
          elsif status >= 300
            puts "🔄 REDIRECT RESPONSE:"
            puts "   Location: #{headers['Location']}"
          else
            puts "✅ SUCCESS RESPONSE"
          end
          puts ""
          
          [status, headers, response]
        end
      end
      )
      
      puts "✅ Test journey logging middleware installed"
    else
      puts "⚠️ Skipping middleware installation - stack is frozen"
    end
  end
  
  # Log all controller actions
  ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, data|
    duration = (finished - started) * 1000
    
    puts "\n🎮 CONTROLLER ACTION:"
    puts "   Controller: #{data[:controller]}"
    puts "   Action: #{data[:action]}"
    puts "   Method: #{data[:method]}"
    puts "   Path: #{data[:path]}"
    puts "   Status: #{data[:status]}"
    puts "   Duration: #{duration.round(2)}ms"
    puts "   View Runtime: #{data[:view_runtime]&.round(2)}ms"
    puts "   DB Runtime: #{data[:db_runtime]&.round(2)}ms"
    
    if data[:exception]
      puts "❌ CONTROLLER EXCEPTION:"
      puts "   #{data[:exception].first}: #{data[:exception].last}"
    end
    puts ""
  end
  
  # Log view renders
  ActiveSupport::Notifications.subscribe "render_template.action_view" do |name, started, finished, unique_id, data|
    duration = (finished - started) * 1000
    
    puts "🎨 VIEW RENDER:"
    puts "   Template: #{data[:identifier]}"
    puts "   Duration: #{duration.round(2)}ms"
    puts ""
  end
  
  # Log database queries
  ActiveSupport::Notifications.subscribe "sql.active_record" do |name, started, finished, unique_id, data|
    duration = (finished - started) * 1000
    
    # Skip schema queries and very fast queries
    return if data[:name] == "SCHEMA" || duration < 1
    
    puts "🗄️ DATABASE QUERY:"
    puts "   SQL: #{data[:sql][0..200]}"
    puts "   Duration: #{duration.round(2)}ms"
    puts "   Name: #{data[:name]}"
    puts ""
  end
  
  puts "✅ Comprehensive test journey logging initialized"
end