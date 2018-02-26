require 'rails_helper'

describe MorApi do
  before(:each) do
    @params = {}
    @request = 'request'
    @params_action = 'params_action'
  end

  describe '#hash_checking' do
    describe 'has defined method in required params module' do
      before(:each) do
        allow(ApiRequiredParams).to receive(:method_is_defined_in_required_params_module) { true }
      end

      it 'with params' do
        allow(ApiRequiredParams).to receive(:get_required_params_for_api_method) { ['param'] }

        expect(ApiRequiredParams).to receive(:get_required_params_for_api_method)
        expect(MorApi).to_not receive(:check_params_with_all_keys)
        expect(MorApi).to receive(:compare_system_and_hashes).with(['param'], {}, {}, @request).once
        MorApi.hash_checking(@params, @request, @params_action)
      end

      it 'without params' do
        allow(ApiRequiredParams).to receive(:get_required_params_for_api_method) { [] }

        expect(ApiRequiredParams).to receive(:get_required_params_for_api_method)
        expect(MorApi).to_not receive(:check_params_with_all_keys)
        expect(MorApi).to receive(:compare_system_and_hashes).with([], {}, {}, @request).once
        MorApi.hash_checking(@params, @request, @params_action)
      end
    end

    describe 'has undefined method in required params module' do
      before(:each) do
        allow(ApiRequiredParams).to receive(:method_is_defined_in_required_params_module) { false }
      end

      it 'with params' do
        allow(MorApi).to receive(:check_params_with_all_keys) { [['param'], {}, {}] }

        expect(ApiRequiredParams).to_not receive(:get_required_params_for_api_method)
        expect(MorApi).to receive(:check_params_with_all_keys).once
        expect(MorApi).to receive(:compare_system_and_hashes).with(['param'], {}, {}, @request).once
        MorApi.hash_checking(@params, @request, @params_action)
      end

      it 'without params' do
        allow(MorApi).to receive(:check_params_with_all_keys) { [[], {}, {}] }

        expect(ApiRequiredParams).to_not receive(:get_required_params_for_api_method)
        expect(MorApi).to receive(:check_params_with_all_keys).once
        expect(MorApi).to receive(:compare_system_and_hashes).with([], {}, {}, @request).once
        MorApi.hash_checking(@params, @request, @params_action)
      end
    end
  end
end
