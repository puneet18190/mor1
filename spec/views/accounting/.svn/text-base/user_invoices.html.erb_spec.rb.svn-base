require 'spec_helper'
require 'rails_helper'

describe 'accounting/user_invoices' do
	it 'shows invoices for partner' do
		FactoryGirl.create(:user)
        @invoices = [FactoryGirl.create(:invoice)]
		render
		expect(rendered).to include('Partner')
	end
end