module PbxFunctionsHelper

  def get_type_and_nice_name(object)
    if object.class.name == 'Device'
      ('User Device: ' + link_nice_device(object)).delete("\n")
    elsif object.type == 'ringgroup'
      link_to "Ring Group: " + object.name , {:controller => :ringgroups, :action => :edit, :id => object.data1}
    elsif object.type == 'queue'
      link_to "Queue: " + object.name , {:controller => :ast_queues, :action => :edit, :id => object.data1}
    elsif object.type == 'pbxfunction'
      link_to "External DID: " + object.name , {:controller => :functions, :action => :pbx_function_edit, :id => object.id}
    end
  end

  def edit_links(object)
    if object.class.name == 'Device'
      link_to b_edit, :controller => "devices", :action => "device_edit", :id => object.id
    elsif object.type == 'ringgroup'
      link_to b_edit, {:controller => :ringgroups, :action => :edit, :id => object.data1}
    elsif object.type == 'queue'
      link_to b_edit, {:controller => :ast_queues, :action => :edit, :id => object.data1}
    elsif object.type == 'pbxfunction'
      link_to b_edit, {:controller => :functions, :action => :pbx_function_edit, :id => object.id}
    end
  end
end