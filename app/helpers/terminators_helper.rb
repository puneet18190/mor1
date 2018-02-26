# -*- encoding : utf-8 -*-
module TerminatorsHelper
  def terminator_delete(term)
    user = accountant? ? User.where(id: 0).first : current_user
    if user.id.to_i == term.user_id.to_i
      link_to b_delete, {:action => :destroy, :id => term.id}, data: {confirm: _('are_you_sure')}, :method => :post, :id => "delete_link_" + term.id.to_s
    else
      ""
    end
  end

  def terminator_edit(term)
    user = accountant? ? User.where(id: 0).first : current_user
    if user.id.to_i == term.user_id.to_i
      link_to b_edit, {:action => :edit, :id => term.id}, {:id => "edit_link_" + term.id.to_s}
    else
      ""
    end
  end
end
