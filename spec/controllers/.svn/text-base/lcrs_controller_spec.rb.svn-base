require 'rails_helper'

  describe LcrsController do
	describe '#create' do
	  it 'creates lcr with same id' do
	    lcr = Lcr.create(id: 1)
	    lcr_test = Lcr.create(id: 1)
	    expect(lcr.id).to_not eq(lcr_test.id)
	  end
	end
  end