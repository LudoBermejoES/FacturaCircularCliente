module RequestHelper
  def self.included(base)
    base.before(:each) do
      host! 'localhost:3002'
    end
  end
end

RSpec.configure do |config|
  config.include RequestHelper, type: :request
end