require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe 'admin navigation helpers' do
    describe '#admin_nav_class' do
      it 'returns active classes for current page' do
        allow(helper).to receive(:current_page?).with('/admin/users').and_return(true)
        
        result = helper.admin_nav_class('/admin/users')
        expect(result).to include('text-red-600')
        expect(result).to include('border-b-2')
        expect(result).to include('border-red-600')
      end

      it 'returns inactive classes for non-current page' do
        allow(helper).to receive(:current_page?).with('/admin/users').and_return(false)
        
        result = helper.admin_nav_class('/admin/users')
        expect(result).to include('text-gray-500')
        expect(result).to include('hover:text-red-600')
        expect(result).not_to include('border-b-2')
      end
    end

    describe '#admin_card_classes' do
      it 'returns consistent card styling classes' do
        result = helper.admin_card_classes
        expect(result).to include('bg-white')
        expect(result).to include('rounded-xl')
        expect(result).to include('shadow-sm')
        expect(result).to include('border')
      end
    end

    describe '#admin_button_primary_classes' do
      it 'returns primary button styling classes' do
        result = helper.admin_button_primary_classes
        expect(result).to include('bg-red-600')
        expect(result).to include('hover:bg-red-700')
        expect(result).to include('text-white')
      end
    end

    describe '#admin_button_secondary_classes' do
      it 'returns secondary button styling classes' do
        result = helper.admin_button_secondary_classes
        expect(result).to include('bg-white')
        expect(result).to include('border-gray-300')
        expect(result).to include('text-gray-700')
      end
    end

    describe '#admin_status_badge' do
      it 'returns green badge for active status' do
        result = helper.admin_status_badge('active')
        expect(result).to include('bg-green-100')
        expect(result).to include('text-green-800')
        expect(result).to include('Active')
      end

      it 'returns red badge for inactive status' do
        result = helper.admin_status_badge('inactive')
        expect(result).to include('bg-red-100')
        expect(result).to include('text-red-800')
        expect(result).to include('Inactive')
      end

      it 'returns yellow badge for pending status' do
        result = helper.admin_status_badge('pending')
        expect(result).to include('bg-yellow-100')
        expect(result).to include('text-yellow-800')
        expect(result).to include('Pending')
      end

      it 'accepts custom text' do
        result = helper.admin_status_badge('active', 'Custom Text')
        expect(result).to include('Custom Text')
      end
    end
  end
end