require 'rails_helper'

RSpec.describe PaginationHelper, type: :helper do
  # Mock paginated collection that behaves like Kaminari collection
  let(:mock_collection) do
    double('PaginatedCollection').tap do |collection|
      allow(collection).to receive(:total_pages).and_return(total_pages)
      allow(collection).to receive(:total_count).and_return(total_count)
      allow(collection).to receive(:current_page).and_return(current_page)
      allow(collection).to receive(:limit_value).and_return(per_page)
      allow(collection).to receive(:size).and_return([items_on_page, per_page].min)
      allow(collection).to receive(:prev_page).and_return(prev_page)
      allow(collection).to receive(:next_page).and_return(next_page)
      allow(collection).to receive(:first_page?).and_return(current_page == 1)
      allow(collection).to receive(:last_page?).and_return(current_page == total_pages)
    end
  end

  # Default collection values
  let(:total_pages) { 5 }
  let(:total_count) { 48 }
  let(:current_page) { 3 }
  let(:per_page) { 10 }
  let(:items_on_page) { 10 }
  let(:prev_page) { 2 }
  let(:next_page) { 4 }

  before do
    # Mock Rails params and url helpers
    allow(helper).to receive(:params).and_return(ActionController::Parameters.new(page: current_page.to_s))
    allow(helper).to receive(:url_for).and_return('/test_path?page=1')
    allow(helper).to receive(:link_to).and_return('<a href="#">Link</a>'.html_safe)
  end

  describe '#paginate' do
    context 'with default options' do
      it 'renders pagination with default options' do
        expect(helper).to receive(:render).with(
          'shared/pagination',
          {
            collection: mock_collection,
            param_name: :page,
            window: 2
          }
        )
        helper.paginate(mock_collection)
      end

      it 'passes collection and default options to partial' do
        expect(helper).to receive(:render) do |partial, locals|
          expect(partial).to eq('shared/pagination')
          expect(locals[:collection]).to eq(mock_collection)
          expect(locals[:param_name]).to eq(:page)
          expect(locals[:window]).to eq(2)
        end
        helper.paginate(mock_collection)
      end
    end

    context 'with custom options' do
      it 'accepts custom param_name and window options' do
        custom_options = { param_name: :p, window: 5 }
        
        expect(helper).to receive(:render).with(
          'shared/pagination',
          {
            collection: mock_collection,
            param_name: :p,
            window: 5
          }
        )
        helper.paginate(mock_collection, custom_options)
      end

      it 'merges custom options with defaults' do
        expect(helper).to receive(:render).with(
          'shared/pagination',
          {
            collection: mock_collection,
            param_name: :custom_page,
            window: 2
          }
        )
        helper.paginate(mock_collection, { param_name: :custom_page })
      end
    end

    context 'with empty options hash' do
      it 'uses default options when empty hash provided' do
        expect(helper).to receive(:render).with(
          'shared/pagination',
          {
            collection: mock_collection,
            param_name: :page,
            window: 2
          }
        )
        helper.paginate(mock_collection, {})
      end
    end

    context 'always renders' do
      let(:total_pages) { 1 }

      it 'renders even for single page collections' do
        expect(helper).to receive(:render).with(
          'shared/pagination',
          {
            collection: mock_collection,
            param_name: :page,
            window: 2
          }
        )
        helper.paginate(mock_collection)
      end
    end

    context 'with zero pages' do
      let(:total_pages) { 0 }

      it 'still renders pagination partial' do
        expect(helper).to receive(:render).with(
          'shared/pagination',
          {
            collection: mock_collection,
            param_name: :page,
            window: 2
          }
        )
        helper.paginate(mock_collection)
      end
    end
  end

  describe '#page_entries_info' do
    context 'with normal pagination' do
      let(:current_page) { 2 }
      let(:per_page) { 10 }
      let(:total_count) { 25 }
      let(:items_on_page) { 10 }

      it 'shows correct entry range for middle page' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('Showing <b>11</b> to <b>20</b> of <b>25</b> entries')
        expect(result).to be_html_safe
      end
    end

    context 'with first page' do
      let(:current_page) { 1 }
      let(:per_page) { 10 }
      let(:total_count) { 25 }
      let(:items_on_page) { 10 }

      it 'shows correct entry range for first page' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('Showing <b>1</b> to <b>10</b> of <b>25</b> entries')
      end
    end

    context 'with last page (partial)' do
      let(:current_page) { 3 }
      let(:per_page) { 10 }
      let(:total_count) { 25 }
      let(:items_on_page) { 5 }

      it 'shows correct entry range for partial last page' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('Showing <b>21</b> to <b>25</b> of <b>25</b> entries')
      end
    end

    context 'with single item page' do
      let(:current_page) { 1 }
      let(:per_page) { 10 }
      let(:total_count) { 1 }
      let(:items_on_page) { 1 }

      it 'shows single entry correctly' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('Showing <b>1</b> to <b>1</b> of <b>1</b> entries')
      end
    end

    context 'with empty collection' do
      let(:current_page) { 1 }
      let(:per_page) { 10 }
      let(:total_count) { 0 }
      let(:items_on_page) { 0 }

      it 'shows no entries message' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('No entries found')
        # Note: 'No entries found' string is not made html_safe in the actual implementation
      end
    end

    context 'edge case: exact page boundary' do
      let(:current_page) { 2 }
      let(:per_page) { 10 }
      let(:total_count) { 20 }
      let(:items_on_page) { 10 }

      it 'calculates correct range at exact boundary' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('Showing <b>11</b> to <b>20</b> of <b>20</b> entries')
      end
    end

    context 'with large page numbers' do
      let(:current_page) { 100 }
      let(:per_page) { 50 }
      let(:total_count) { 5000 }
      let(:items_on_page) { 50 }

      it 'handles large page numbers correctly' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to eq('Showing <b>4951</b> to <b>5000</b> of <b>5000</b> entries')
      end
    end

    context 'HTML safety and formatting' do
      it 'returns HTML-safe string' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to be_html_safe
      end

      it 'includes bold formatting for numbers' do
        result = helper.page_entries_info(mock_collection)
        expect(result).to include('<b>')
        expect(result).to include('</b>')
      end
    end
  end

  describe 'integration with Rails helpers' do
    context 'params handling' do
      it 'works with ActionController::Parameters' do
        params = ActionController::Parameters.new(search: 'test', page: '2')
        allow(helper).to receive(:params).and_return(params)
        
        # Should not raise errors when accessing params
        expect { helper.paginate(mock_collection) }.not_to raise_error
      end
    end

    context 'error handling' do
      it 'raises error when collection lacks required methods' do
        invalid_collection = double('InvalidCollection')
        
        expect {
          helper.page_entries_info(invalid_collection)
        }.to raise_error(RSpec::Mocks::MockExpectationError)
      end

      it 'raises error with nil collection in page_entries_info' do
        expect {
          helper.page_entries_info(nil)
        }.to raise_error(NoMethodError)
      end
    end
  end
end