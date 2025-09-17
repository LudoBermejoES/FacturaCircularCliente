class WorkflowStateForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :integer
  attribute :name, :string
  attribute :code, :string
  attribute :category, :string
  attribute :color, :string, default: '#6B7280'
  attribute :position, :integer, default: 1
  attribute :is_initial, :boolean, default: false
  attribute :is_final, :boolean, default: false
  attribute :display_name, :string

  def persisted?
    false
  end

  def to_param
    nil
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "WorkflowState")
  end

  # Support hash-style access for compatibility with forms
  def [](key)
    send(key) if respond_to?(key)
  end

  # Create from API hash data
  def self.from_hash(hash)
    new(
      id: hash[:id] || hash['id'],
      name: hash[:name] || hash['name'],
      code: hash[:code] || hash['code'],
      category: hash[:category] || hash['category'],
      color: hash[:color] || hash['color'] || '#6B7280',
      position: hash[:position] || hash['position'] || 1,
      is_initial: hash[:is_initial] || hash['is_initial'] || false,
      is_final: hash[:is_final] || hash['is_final'] || false,
      display_name: hash[:display_name] || hash['display_name']
    )
  end
end