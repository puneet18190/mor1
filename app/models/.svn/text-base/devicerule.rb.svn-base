class Devicerule < ActiveRecord::Base
  belongs_to :device
  attr_accessible :device_id, :name, :enabled, :cut, :add, :minlen, :maxlen, :pr_type

  def change_status
    self.enabled ^= 1
  end

  def update_by(params)
    self.name = params[:name].to_s.strip
    self.cut = params[:cut].to_s.strip if params[:cut]
    self.add = params[:add].to_s.strip if params[:add]
    self.minlen = params[:minlen].to_s.strip if params[:minlen].length > 0
    self.maxlen = params[:maxlen].to_s.strip if params[:maxlen].length > 0
    self.change_callerid_name = params[:change_callerid_name].to_i
  end

  def cut_eq_add
    cut == add
  end
end
