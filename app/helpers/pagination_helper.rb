module PaginationHelper
  def paginate(collection, options = {})
    render 'shared/pagination', {
      collection: collection,
      param_name: options[:param_name] || :page,
      window: options[:window] || 2
    }
  end
  
  def page_entries_info(collection)
    if collection.total_count.zero?
      "No entries found"
    else
      from = (collection.current_page - 1) * collection.limit_value + 1
      to = [from + collection.size - 1, collection.total_count].min
      
      "Showing <b>#{from}</b> to <b>#{to}</b> of <b>#{collection.total_count}</b> entries".html_safe
    end
  end
end