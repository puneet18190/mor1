require 'rails_helper'

describe StatsController do
  describe 'loss calls pagination work' do
    it 'loss calls method works' do
      session[:user_id] = 0
      session[:items_per_page] = 50
      expect(controller.loss_making_calls).to eq(nil)
    end
    it 'pagination method is called and returned correct data' do
      options = {page: nil}
      login_as_admin
      expect(Application).to receive(:pages_validator).with(session, options, 2)
      get :loss_making_calls
    end
    it 'test if items_per_page is very big' do
      options = {page: nil}
      login_as_admin
      session[:items_per_page] = 156156156156156156156165
      expect(Application).to receive(:pages_validator).with(session, options, 2)
      get :loss_making_calls
    end
    it 'test if items_per_page is 0' do
      options = {page: nil}
      login_as_admin
      session[:items_per_page] = 0
      expect(Application).to receive(:pages_validator).with(session, options, 2)
      get :loss_making_calls
    end
    it 'test if items_per_page is negative' do
      options = {page: nil}
      login_as_admin
      session[:items_per_page] = -156156156156156156156165
      expect(Application).to receive(:pages_validator).with(session, options, 2)
      get :loss_making_calls
    end
  end

  describe '#active_calls_show' do
    it 'passes nil as current_user.spy_device_id' do
      current_user = User.new
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(controller.current_user).to receive(:spy_device_id).and_return(nil)
      expect{ get :active_calls_show }.to_not raise_error
    end
  end

  describe '#set_minutes_from_calldate' do
    describe 'when calldate tz is' do
      it 'same as user tz' do
        current_user = User.new
        allow(controller).to receive(:current_user).and_return(current_user)
        calldate = '2012-11-30 15:49:30 +0200'.to_time
        expect(controller.set_minutes_from_calldate(calldate)).to eq(829)
      end

      it 'not same as user tz' do
        current_user = User.new
        allow(controller).to receive(:current_user).and_return(current_user)
        calldate = '2012-11-30 15:49:30 +0400'.to_time
        expect(controller.set_minutes_from_calldate(calldate)).to_not eq(829)
      end
    end
  end
end
