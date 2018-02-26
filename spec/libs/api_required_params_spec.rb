require 'rails_helper'

describe ApiRequiredParams do
  before(:each) do
    allow(ApiRequiredParams).to receive(:required_params_for_api_method) {
      { defined_method: %w[], defined_method_with_param: %w[param] }
    }
  end

  describe '#method_is_defined_in_required_params_module' do
    it 'has defined method' do
      method = 'defined_method'
      expect(ApiRequiredParams.method_is_defined_in_required_params_module(method)).to be true
    end

    it 'has undefined method' do
      method = 'undefined_method'
      expect(ApiRequiredParams.method_is_defined_in_required_params_module(method)).to be false
    end

    it 'has empty param' do
      method = nil
      expect(ApiRequiredParams.method_is_defined_in_required_params_module(method)).to be false
    end
  end

  describe '#get_required_params_for_api_method' do
    it 'has defined method without params' do
      method = 'defined_method'
      expect(ApiRequiredParams.get_required_params_for_api_method(method)).to eq([])
    end

    it 'has defined method with params' do
      method = 'defined_method_with_param'
      expect(ApiRequiredParams.get_required_params_for_api_method(method)).to eq(['param'])
    end

    it 'has undefined method' do
      method = 'undefined_method'
      expect(ApiRequiredParams.get_required_params_for_api_method(method)).to eq([])
    end

    it 'has empty param' do
      method = nil
      expect(ApiRequiredParams.get_required_params_for_api_method(method)).to eq([])
    end
  end
end
