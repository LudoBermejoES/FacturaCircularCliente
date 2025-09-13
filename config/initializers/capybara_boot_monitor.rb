if Rails.env.test?
  puts "🔍 BOOT MONITOR: Starting Rails initialization at #{Time.current}"
  
  # Monitor Rails initialization stages
  Rails.application.config.before_configuration do
    puts "🔍 BOOT MONITOR: before_configuration at #{Time.current}"
  end
  
  Rails.application.config.before_initialize do
    puts "🔍 BOOT MONITOR: before_initialize at #{Time.current}"
  end
  
  Rails.application.config.to_prepare do
    puts "🔍 BOOT MONITOR: to_prepare at #{Time.current}"
  end
  
  Rails.application.config.after_initialize do
    puts "🔍 BOOT MONITOR: after_initialize at #{Time.current}"
    puts "🔍 BOOT MONITOR: Rails application fully initialized"
  end
  
  # Monitor server startup for Capybara
  if defined?(Puma)
    puts "🔍 BOOT MONITOR: Puma server gem detected at #{Time.current}"
  end
  
  puts "🔍 BOOT MONITOR: Boot monitor installed at #{Time.current}"
end