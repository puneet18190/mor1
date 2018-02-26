require 'rails_helper'

describe ServicesController do
  describe '#activations_param_order_fix' do
    it 'order must be correct' do
      params = {
        activation_start: {year: '2016', day: '6', hour: '6', month: '6', minute: '6'},
        activation_end: {day: '7', year: '2017', minute: '7',month: '7', hour: '7'}
      }
      allow(controller).to receive(:params) { params }
      controller.instance_eval{activations_param_order_fix}
      good_output = {:activation_start=>{:year=>"2016", :month=>"6", :day=>"6", :hour=>"6", :minute=>"6"}, :activation_end=>{:year=>"2017", :month=>"7", :day=>"7", :hour=>"7", :minute=>"7"}}
      expect(controller.params).to eq good_output
    end
    it 'no activation_end' do
      params = {activation_start: {year: '2016', day: '6', hour: '6', month: '6', minute: '6'}}
      allow(controller).to receive(:params) { params }
      controller.instance_eval{activations_param_order_fix}
      good_output = {:activation_start=>{:year=>"2016", :month=>"6", :day=>"6", :hour=>"6", :minute=>"6"}}
      expect(controller.params).to eq good_output
    end
  end
end
