# -*- encoding : utf-8 -*-
module RinggroupsHelper
  def pbx_pool_name(pool_id)
    PbxPool.where(id: pool_id).first.try(:name).to_s
  end
end
