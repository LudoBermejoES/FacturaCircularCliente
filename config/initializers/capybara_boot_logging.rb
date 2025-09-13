if false # Rails.env.test? - DISABLED due to IOError in TCP logging
  puts "🔍 CAPYBARA BOOT LOGGING: Initializer loaded at #{Time.current}"
  
  # Log the Rails boot process
  Rails.application.config.after_initialize do
    puts "🔍 CAPYBARA BOOT LOGGING: Rails after_initialize callback at #{Time.current}"
    puts "   - Rails.application.initialized?: #{Rails.application.initialized?}"
    puts "   - Middleware stack count: #{Rails.application.middleware.count}"
    puts "   - Routes loaded: #{Rails.application.routes.routes.count rescue 'Error'}"
  end
  
  # Monitor Puma server startup if we can
  if defined?(Puma)
    puts "🔍 CAPYBARA BOOT LOGGING: Puma detected, setting up monitoring"
    
    # Hook into Puma events if possible
    original_puma_launcher = Puma::Launcher.method(:new) rescue nil
    if original_puma_launcher
      Puma::Launcher.define_singleton_method(:new) do |*args, **kwargs|
        puts "🔍 PUMA: Launcher.new called with args: #{args.inspect}"
        launcher = original_puma_launcher.call(*args, **kwargs)
        puts "🔍 PUMA: Launcher created: #{launcher.class}"
        launcher
      end
    end
  end
  
  # Monitor server binding
  if defined?(TCPServer)
    class TCPServer
      alias_method :original_initialize, :initialize
      
      def initialize(*args)
        puts "🔍 TCP SERVER: Binding to #{args.inspect} at #{Time.current}"
        start_time = Time.current
        
        begin
          result = original_initialize(*args)
          bind_time = Time.current - start_time
          puts "🔍 TCP SERVER: Successfully bound in #{bind_time.round(3)}s to #{self.addr.inspect}"
          result
        rescue => e
          bind_time = Time.current - start_time
          puts "🔍 TCP SERVER: Failed to bind after #{bind_time.round(3)}s: #{e.class}: #{e.message}"
          raise
        end
      end
    end
  end
  
  # Monitor Rack application calls during server startup
  class Rails::Application
    alias_method :original_call, :call
    
    def call(env)
      request_start = Time.current
      method = env['REQUEST_METHOD']
      path = env['PATH_INFO']
      
      # Only log the first few requests to avoid spam
      @request_count ||= 0
      @request_count += 1
      
      if @request_count <= 10
        puts "🔍 RAILS APP CALL ##{@request_count}: #{method} #{path} at #{request_start}"
      end
      
      begin
        status, headers, body = original_call(env)
        
        if @request_count <= 10
          response_time = Time.current - request_start
          puts "🔍 RAILS APP RESPONSE ##{@request_count}: #{status} in #{response_time.round(3)}s"
        end
        
        [status, headers, body]
      rescue => e
        if @request_count <= 10
          response_time = Time.current - request_start
          puts "🔍 RAILS APP ERROR ##{@request_count}: #{e.class}: #{e.message} after #{response_time.round(3)}s"
        end
        raise
      end
    end
  end
  
  # Monitor thread creation (servers often use threads)
  original_thread_new = Thread.method(:new)
  Thread.define_singleton_method(:new) do |*args, &block|
    thread_id = "#{Time.current.to_i}-#{rand(1000)}"
    puts "🔍 THREAD: Creating new thread #{thread_id}"
    
    original_thread_new.call(*args) do |*thread_args|
      begin
        puts "🔍 THREAD: Thread #{thread_id} started"
        result = block.call(*thread_args)
        puts "🔍 THREAD: Thread #{thread_id} completed normally"
        result
      rescue => e
        puts "🔍 THREAD: Thread #{thread_id} failed: #{e.class}: #{e.message}"
        raise
      end
    end
  end
  
  puts "🔍 CAPYBARA BOOT LOGGING: All hooks installed at #{Time.current}"
end