require 'rails_helper'

describe EmailsController do
    describe '#list' do
        it 'stores emails' do
            allow(controller).to receive(:authorize).and_return(true)
            FactoryGirl.create(:action)
            get :list, {}, {user_id: 0}
            warning_email_count = assigns(:emails).detect { |email| email[:id] == 7 } [:emails]
            expect(warning_email_count).to be > 0
        end
    end
end