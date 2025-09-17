module ApplicationHelper
  def number_with_delimiter(number, delimiter: ',')
    return '' if number.nil?
    parts = number.to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
    parts.join('.')
  end
  
  def format_currency(amount, currency = '€')
    return '-' if amount.nil?
    "#{number_with_delimiter(sprintf('%.2f', amount))} #{currency}"
  end
  
  def format_percentage(percentage)
    return '-' if percentage.nil?
    "#{sprintf('%.2f', percentage)}%"
  end
  
  def format_date(date)
    return '-' if date.nil?
    Date.parse(date.to_s).strftime('%B %d, %Y')
  rescue
    date.to_s
  end
  
  def format_date_short(date)
    return '-' if date.nil?
    Date.parse(date.to_s).strftime('%b %d, %Y')
  rescue
    date.to_s
  end
  
  def status_badge_class(status)
    base_classes = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
    
    case status.to_s.downcase
    when 'draft'
      "#{base_classes} bg-gray-100 text-gray-800"
    when 'sent'
      "#{base_classes} bg-blue-100 text-blue-800"
    when 'viewed'
      "#{base_classes} bg-purple-100 text-purple-800"
    when 'partial'
      "#{base_classes} bg-yellow-100 text-yellow-800"
    when 'paid'
      "#{base_classes} bg-green-100 text-green-800"
    when 'overdue'
      "#{base_classes} bg-red-100 text-red-800"
    when 'cancelled'
      "#{base_classes} bg-gray-100 text-gray-800"
    when 'frozen'
      "#{base_classes} bg-indigo-100 text-indigo-800"
    else
      "#{base_classes} bg-gray-100 text-gray-800"
    end
  end
  
  def breadcrumb(*items)
    content_for :breadcrumb do
      content_tag :nav, class: "flex mb-6", "aria-label": "Breadcrumb" do
        content_tag :ol, class: "inline-flex items-center space-x-1 md:space-x-3" do
          items.map.with_index do |item, index|
            if index == items.length - 1
              # Last item (current page)
              content_tag :li, class: "inline-flex items-center" do
                content_tag :span, item.is_a?(Array) ? item.first : item, 
                  class: "text-sm font-medium text-gray-700"
              end
            else
              # Linkable items
              content_tag :li, class: "inline-flex items-center" do
                if item.is_a?(Array)
                  link = link_to item.first, item.last, 
                    class: "inline-flex items-center text-sm font-medium text-gray-700 hover:text-indigo-600"
                  if index > 0
                    chevron = content_tag :svg, class: "w-3 h-3 text-gray-400 mx-1", fill: "currentColor", viewBox: "0 0 20 20" do
                      content_tag :path, nil, "fill-rule": "evenodd", 
                        d: "M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z",
                        "clip-rule": "evenodd"
                    end
                    chevron + link
                  else
                    link
                  end
                else
                  if index > 0
                    chevron = content_tag :svg, class: "w-3 h-3 text-gray-400 mx-1", fill: "currentColor", viewBox: "0 0 20 20" do
                      content_tag :path, nil, "fill-rule": "evenodd",
                        d: "M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z",
                        "clip-rule": "evenodd"
                    end
                    chevron + content_tag(:span, item, class: "text-sm font-medium text-gray-700")
                  else
                    content_tag :span, item, class: "text-sm font-medium text-gray-700"
                  end
                end
              end
            end
          end.join.html_safe
        end
      end
    end
  end
  
  def flash_class(type)
    case type.to_s
    when 'notice', 'success'
      'bg-green-50 text-green-800 border-green-200'
    when 'alert', 'error'
      'bg-red-50 text-red-800 border-red-200'
    when 'warning'
      'bg-yellow-50 text-yellow-800 border-yellow-200'
    else
      'bg-blue-50 text-blue-800 border-blue-200'
    end
  end
  
  def flash_icon(type)
    case type.to_s
    when 'notice', 'success'
      '<svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
      </svg>'
    when 'alert', 'error'
      '<svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
      </svg>'
    when 'warning'
      '<svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
      </svg>'
    else
      '<svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
      </svg>'
    end.html_safe
  end
  
  # Helper to add error styling to form fields
  def field_class(field_name, base_classes, errors = nil)
    classes = base_classes

    if errors && errors[field_name.to_s]
      # Add error styling: red border and red focus ring
      classes = classes.gsub('border-gray-300', 'border-red-300')
      classes = classes.gsub('focus:border-indigo-500', 'focus:border-red-500')
      classes = classes.gsub('focus:ring-indigo-500', 'focus:ring-red-500')
    else
      # Ensure default styling
      unless classes.include?('border-')
        classes += ' border-gray-300'
      end
      unless classes.include?('focus:border-')
        classes += ' focus:border-indigo-500'
      end
    end

    classes
  end

  # Helper to access hash values with both symbol and string keys
  def safe_access(hash, key)
    return nil unless hash.is_a?(Hash)
    hash[key.to_sym] || hash[key.to_s]
  end
end
