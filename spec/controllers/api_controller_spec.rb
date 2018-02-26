require 'rails_helper'

describe ApiController do
  describe '#new_subscription_params_validate' do
    before(:each) do
      allow(assigns(:user)).to receive(:get_corrected_owner_id) { 0 }
      allow(assigns(:doc)).to receive(:error) { [] }


    end

    it 'pass all validations' do
      params = {service_id: 1, user_id: 2, subscription_activation_start: 1413466954,
                subscription_activation_end: 1413553354, subscription_until_canceled: 0,
                subscription_no_expiration_at_the_end_of_a_month: 0}

      expect(controller.instance_eval{new_subscription_params_validate(params)}).to be true
    end
    it 'activation date is higher than end' do
      params = {service_id: 1, user_id: 2, subscription_activation_start: 1413553354,
                subscription_activation_end: 1413466954, subscription_until_canceled: 0,
                subscription_no_expiration_at_the_end_of_a_month: 0}

      expect(controller.instance_eval{new_subscription_params_validate(params)}).to be false
    end
    it 'no params' do
      params = { }

      expect(controller.instance_eval{new_subscription_params_validate(params)}).to be false
    end

    it 'no service_id params update action' do
      service = FactoryGirl.create(:service, id: 2)
      allow(assigns(:subscription)).to receive(:service) { service }
      params = {subscription_activation_start: 1413520924,
                subscription_activation_end: 1413520925, subscription_until_canceled: 1}

      expect(controller.instance_eval{new_subscription_params_validate(params, 'update')}).to be true
    end

    it 'no service id params create action' do
      params = {subscription_activation_start: 1413520924,
                subscription_activation_end: 1413520925, subscription_until_canceled: 1}

      expect(controller.instance_eval{new_subscription_params_validate(params)}).to be false
    end
  end

  describe '#new_subscription_params' do
    it 'possible good params' do
      params = {service_id: 1, user_id:1, subscription_activation_start: 1413520924,
                subscription_activation_end: 1413520925, subscription_until_canceled: 0}
      expected = {service_id: 1, user_id: 1, activation_start: '2014-10-17 04:42', activation_end: '2014-10-17 04:42', memo: '', no_expire: 0}


      expect(controller.instance_eval{new_subscription_params(params)}).to include(expected)
    end
    it 'wrong subscription_until_canceled param' do
      params = {service_id: 1, user_id:1, subscription_activation_start: 1413520924, subscription_memo: ' asd ',
                subscription_activation_end: 1413520925, subscription_until_canceled: 5}
      expected = {service_id: 1, user_id: 1, activation_start: '2014-10-17 04:42', activation_end: '2014-10-17 04:42', memo: 'asd', no_expire: 0}

      expect(controller.instance_eval{new_subscription_params(params)}).to include(expected)
    end
    it 'good subscription_until_canceled param' do
      params = {service_id: 1, user_id:1, subscription_activation_start: 1413520924,
                subscription_activation_end: 1413520925, subscription_until_canceled: 1}
      expected = {service_id: 1, user_id: 1, activation_start: '2014-10-17 04:42', activation_end: nil, memo: '', no_expire: 0}

      expect(controller.instance_eval{new_subscription_params(params)}).to include(expected)
    end
  end

  describe '#update_subscription_params' do
    it 'possible good params' do
      params = {subscription_activation_start: 1413520924,
                subscription_activation_end: 1413520925, subscription_until_canceled: 0}
      expected = {activation_start: '2014-10-17 04:42', activation_end: '2014-10-17 04:42'}
      allow(controller).to receive(:params) { params }
      expect(controller.instance_eval{update_subscription_params(params)}).to eq expected

    end
    it 'wrong subscription_until_canceled param' do
      params = {subscription_activation_start: 1413520924, subscription_memo: ' asd ',
                subscription_activation_end: 1413520925, subscription_until_canceled: 5}
      expected = {activation_start: '2014-10-17 04:42', activation_end: '2014-10-17 04:42', memo: 'asd'}

      allow(controller).to receive(:params) { params }
      expect(controller.instance_eval{update_subscription_params(params)}).to eq expected
    end
    it 'good subscription_until_canceled param' do
      params = {subscription_activation_start: 1413520924,
                subscription_activation_end: 1413520925, subscription_until_canceled: 1}
      expected = {activation_start: '2014-10-17 04:42', activation_end: nil}

      allow(controller).to receive(:params) { params }
      expect(controller.instance_eval{update_subscription_params(params)}).to eq expected

    end
     it 'good subscription_until_canceled param no activation dates' do
      params = {subscription_until_canceled: 1}
      expected = {activation_end: nil}

      allow(controller).to receive(:params) { params }
      expect(controller.instance_eval{update_subscription_params(params)}).to eq expected
    end
  end

  describe '#subscription_delete_validate_params' do
    it 'pass all validations' do
      params = {subscription_id: 1, subscription_delete_action: 1}
      allow(controller).to receive(:params) { params }
      allow(assigns(:user)).to receive(:get_corrected_owner_id) { 0 }
      controller.instance_eval{subscription_delete_validate_params}
      good_output = '{:subscription=>#<Subscription id: 1, service_id: 1, user_id: 2, device_id: nil, activation_start: "2009-03-22 09:25:00", activation_end: "2013-07-22 09:25:00", added: "2009-04-22 09:25:00", memo: "Test_preriodic_service_memo", no_expire: 0>, :delete_action=>1}'
      expect(controller.instance_eval{subscription_delete_validate_params}.to_s).to eq good_output
    end
  end
end