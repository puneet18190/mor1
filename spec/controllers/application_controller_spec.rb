require 'rails_helper'

describe ApplicationController do
  describe 'finds free extension when' do
    it 'big values' do
      big_values = [['10000000000000000002', '88888888888888888888', '10000000000000000004', '33333333333333333333',
        '10000000000000000001'], 10000000000000000001, 99999999999999999999]

      expect(controller.free_extension(big_values)).to eq('10000000000000000003')
    end

    it 'no values' do
      no_values = [[], 0, 1]

      expect(controller.free_extension(no_values)).to eq('1')
    end
  end

  describe 'multilevel reseller' do
    FactoryGirl.create(:confline)
    it 'is active' do
      expect(controller.instance_eval{ multi_level_reseller_active? }).to eq(true)
    end
  end
end
