module BreadcrumbHelper
  def breadcrumb(*items)
    content_for :breadcrumb do
      render 'shared/breadcrumb', items: items
    end
  end
end