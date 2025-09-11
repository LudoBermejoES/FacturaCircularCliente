require 'rails_helper'

RSpec.describe BreadcrumbHelper, type: :helper do
  before do
    # Clear any existing breadcrumb content
    @view_flow = ActionView::OutputFlow.new
    view.instance_variable_set(:@view_flow, @view_flow)
  end

  describe '#breadcrumb' do
    context 'with no items' do
      it 'sets breadcrumb content' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: [] }).and_return('<nav></nav>'.html_safe)
        helper.breadcrumb
        expect(helper.content_for(:breadcrumb)).to be_present
      end

      it 'renders breadcrumb partial with empty items array' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: [] })
        helper.breadcrumb
      end
    end

    context 'with single string item' do
      it 'renders breadcrumb with single string item' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: ['Dashboard'] })
        helper.breadcrumb('Dashboard')
      end

      it 'sets breadcrumb content for layout rendering' do
        allow(helper).to receive(:render).and_return('<nav>Breadcrumb</nav>'.html_safe)
        helper.breadcrumb('Current Page')
        expect(helper.content_for(:breadcrumb)).to be_present
      end
    end

    context 'with single array item' do
      it 'renders breadcrumb with array item' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: [['Invoices', '/invoices']] })
        helper.breadcrumb(['Invoices', '/invoices'])
      end
    end

    context 'with multiple mixed items' do
      it 'handles mixed string and array items' do
        expected_items = [['Invoices', '/invoices'], ['Details', '/invoices/1'], 'Current Page']
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: expected_items })
        helper.breadcrumb(['Invoices', '/invoices'], ['Details', '/invoices/1'], 'Current Page')
      end

      it 'preserves item order and types' do
        expected_items = [['Settings', '/settings'], ['Profile', '/profile']]
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: expected_items })
        helper.breadcrumb(['Settings', '/settings'], ['Profile', '/profile'])
      end
    end

    context 'with special characters and encoding' do
      it 'handles special characters in breadcrumb text' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: ['Factura & Envío'] })
        helper.breadcrumb('Factura & Envío')
      end

      it 'handles unicode characters in breadcrumb paths' do
        expected_items = [['España', '/locales/españa']]
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: expected_items })
        helper.breadcrumb(['España', '/locales/españa'])
      end
    end

    context 'with nil and empty values' do
      it 'handles nil items gracefully' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: [nil] })
        helper.breadcrumb(nil)
      end

      it 'handles empty string items' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: [''] })
        helper.breadcrumb('')
      end
    end

    context 'content_for behavior' do
      before do
        allow(helper).to receive(:render).and_return('<nav>Breadcrumb</nav>'.html_safe)
      end

      it 'sets content for breadcrumb section' do
        helper.breadcrumb('Test')
        content = helper.content_for(:breadcrumb)
        expect(content).to be_present
        expect(content).to be_html_safe
      end

      it 'allows content to be retrieved in layout' do
        helper.breadcrumb(['Companies', '/companies'], 'New Company')
        breadcrumb_content = helper.content_for(:breadcrumb)
        expect(breadcrumb_content).to eq('<nav>Breadcrumb</nav>')
      end
    end

    context 'partial rendering' do
      it 'calls render with correct partial path and locals' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: ['Test'] })
        helper.breadcrumb('Test')
      end

      it 'passes items array directly to partial' do
        items = [['Home', '/'], ['Users', '/users'], 'Profile']
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: items })
        helper.breadcrumb(*items)
      end
    end

    context 'variable arguments handling' do
      it 'handles single argument' do
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: ['Single'] })
        helper.breadcrumb('Single')
      end

      it 'handles multiple arguments' do
        args = ['One', ['Two', '/two'], 'Three']
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: args })
        helper.breadcrumb(*args)
      end

      it 'handles complex mixed argument types' do
        args = [['Link', '/path'], 'Text', ['Another Link', '/another'], 'Final Text']
        expect(helper).to receive(:render).with('shared/breadcrumb', { items: args })
        helper.breadcrumb(*args)
      end
    end
  end
end