require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#number_with_delimiter' do
    it 'formats number with comma delimiter' do
      expect(helper.number_with_delimiter(1234567)).to eq('1,234,567')
    end
    
    it 'handles integers' do
      expect(helper.number_with_delimiter(1000)).to eq('1,000')
    end
    
    it 'handles small numbers' do
      expect(helper.number_with_delimiter(100)).to eq('100')
    end
    
    it 'handles nil values' do
      expect(helper.number_with_delimiter(nil)).to eq('')
    end
    
    it 'accepts custom delimiter' do
      expect(helper.number_with_delimiter(1234567, delimiter: '.')).to eq('1.234.567')
    end
  end
  
  describe '#format_currency' do
    it 'formats amount with euro symbol' do
      expect(helper.format_currency(1234.56)).to eq('1,234.56 €')
    end
    
    it 'handles nil values' do
      expect(helper.format_currency(nil)).to eq('-')
    end
    
    it 'formats with two decimal places' do
      expect(helper.format_currency(100)).to eq('100.00 €')
    end
    
    it 'accepts custom currency symbol' do
      expect(helper.format_currency(100, '$')).to eq('100.00 $')
    end
    
    it 'handles large amounts' do
      expect(helper.format_currency(1234567.89)).to eq('1,234,567.89 €')
    end
  end
  
  describe '#format_percentage' do
    it 'formats percentage with symbol' do
      expect(helper.format_percentage(21)).to eq('21.00%')
    end
    
    it 'handles nil values' do
      expect(helper.format_percentage(nil)).to eq('-')
    end
    
    it 'formats with two decimal places' do
      expect(helper.format_percentage(10.5)).to eq('10.50%')
    end
    
    it 'handles zero' do
      expect(helper.format_percentage(0)).to eq('0.00%')
    end
  end
  
  describe '#format_date' do
    it 'formats date in long format' do
      date = Date.new(2023, 12, 25)
      expect(helper.format_date(date)).to eq('December 25, 2023')
    end
    
    it 'handles string dates' do
      expect(helper.format_date('2023-12-25')).to eq('December 25, 2023')
    end
    
    it 'handles nil values' do
      expect(helper.format_date(nil)).to eq('-')
    end
    
    it 'handles invalid dates gracefully' do
      expect(helper.format_date('invalid')).to eq('invalid')
    end
  end
  
  describe '#format_date_short' do
    it 'formats date in short format' do
      date = Date.new(2023, 12, 25)
      expect(helper.format_date_short(date)).to eq('Dec 25, 2023')
    end
    
    it 'handles string dates' do
      expect(helper.format_date_short('2023-12-25')).to eq('Dec 25, 2023')
    end
    
    it 'handles nil values' do
      expect(helper.format_date_short(nil)).to eq('-')
    end
  end
  
  describe '#status_badge_class' do
    it 'returns correct classes for draft status' do
      result = helper.status_badge_class('draft')
      expect(result).to include('bg-gray-100', 'text-gray-800')
    end
    
    it 'returns correct classes for sent status' do
      result = helper.status_badge_class('sent')
      expect(result).to include('bg-blue-100', 'text-blue-800')
    end
    
    it 'returns correct classes for paid status' do
      result = helper.status_badge_class('paid')
      expect(result).to include('bg-green-100', 'text-green-800')
    end
    
    it 'returns correct classes for overdue status' do
      result = helper.status_badge_class('overdue')
      expect(result).to include('bg-red-100', 'text-red-800')
    end
    
    it 'returns correct classes for frozen status' do
      result = helper.status_badge_class('frozen')
      expect(result).to include('bg-indigo-100', 'text-indigo-800')
    end
    
    it 'handles unknown status with default colors' do
      result = helper.status_badge_class('unknown')
      expect(result).to include('bg-gray-100', 'text-gray-800')
    end
    
    it 'handles symbols as input' do
      result = helper.status_badge_class(:draft)
      expect(result).to include('bg-gray-100', 'text-gray-800')
    end
  end
  
  describe '#flash_class' do
    it 'returns success classes for notice' do
      result = helper.flash_class('notice')
      expect(result).to eq('bg-green-50 text-green-800 border-green-200')
    end
    
    it 'returns success classes for success' do
      result = helper.flash_class('success')
      expect(result).to eq('bg-green-50 text-green-800 border-green-200')
    end
    
    it 'returns error classes for alert' do
      result = helper.flash_class('alert')
      expect(result).to eq('bg-red-50 text-red-800 border-red-200')
    end
    
    it 'returns error classes for error' do
      result = helper.flash_class('error')
      expect(result).to eq('bg-red-50 text-red-800 border-red-200')
    end
    
    it 'returns warning classes for warning' do
      result = helper.flash_class('warning')
      expect(result).to eq('bg-yellow-50 text-yellow-800 border-yellow-200')
    end
    
    it 'returns info classes for other types' do
      result = helper.flash_class('info')
      expect(result).to eq('bg-blue-50 text-blue-800 border-blue-200')
    end
    
    it 'handles symbols as input' do
      result = helper.flash_class(:notice)
      expect(result).to eq('bg-green-50 text-green-800 border-green-200')
    end
  end
  
  describe '#flash_icon' do
    it 'returns checkmark icon for success' do
      result = helper.flash_icon('success')
      expect(result).to include('<svg', 'text-green-400')
      expect(result).to be_html_safe
    end
    
    it 'returns X icon for error' do
      result = helper.flash_icon('error')
      expect(result).to include('<svg', 'text-red-400')
      expect(result).to be_html_safe
    end
    
    it 'returns warning triangle for warning' do
      result = helper.flash_icon('warning')
      expect(result).to include('<svg', 'text-yellow-400')
      expect(result).to be_html_safe
    end
    
    it 'returns info icon for other types' do
      result = helper.flash_icon('info')
      expect(result).to include('<svg', 'text-blue-400')
      expect(result).to be_html_safe
    end
    
    it 'returns HTML safe string' do
      result = helper.flash_icon('success')
      expect(result).to be_html_safe
    end
  end
  
  describe '#breadcrumb' do
    it 'creates breadcrumb with single item' do
      helper.breadcrumb('Dashboard')
      breadcrumb_content = helper.content_for(:breadcrumb)
      expect(breadcrumb_content).to include('Dashboard')
      expect(breadcrumb_content).to include('<nav')
    end
    
    it 'creates breadcrumb with linked items' do
      helper.breadcrumb(['Dashboard', '/dashboard'], 'Invoices')
      breadcrumb_content = helper.content_for(:breadcrumb)
      expect(breadcrumb_content).to include('Dashboard')
      expect(breadcrumb_content).to include('Invoices')
      expect(breadcrumb_content).to include('/dashboard')
    end
    
    it 'adds chevron separators between items' do
      helper.breadcrumb(['Home', '/'], ['Dashboard', '/dashboard'], 'Current')
      breadcrumb_content = helper.content_for(:breadcrumb)
      expect(breadcrumb_content).to include('<svg')
    end
    
    it 'marks last item as non-linked' do
      helper.breadcrumb(['Home', '/'], 'Current Page')
      breadcrumb_content = helper.content_for(:breadcrumb)
      expect(breadcrumb_content).to include('Current Page')
      expect(breadcrumb_content).not_to include('<a href')
    end
  end
end