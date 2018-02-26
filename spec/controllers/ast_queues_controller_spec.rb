require 'rails_helper'

describe AstQueuesController do
  describe 'gets servers for reload when' do
    it 'ccl is active' do
      ccl_active, queue_server_id = [true, 1]
      # gets all asterisk servers
      expect(controller.instance_eval{ get_servers_for_reload(ccl_active, queue_server_id) }).
        to be_a(Array)
    end

    it 'ccl is not active' do
      ccl_active, queue_server_id = [false, 1]
      # gets asterik server which is assigned to queue
      expect(controller.instance_eval{ get_servers_for_reload(ccl_active, queue_server_id) }).to be_a(Server)
    end
  end
end
