# -*- encoding : utf-8 -*-
# User role rights
class RoleRight < ActiveRecord::Base
  attr_accessible :id, :role_id, :right_id, :permission

  belongs_to :role
  belongs_to :right
  validates_uniqueness_of :role_id, scope: :right_id

  # Returns authorization for controller_action
  def RoleRight::get_authorization(role, controller, action)
    sql = "SELECT role_rights.permission FROM role_rights WHERE role_id = #{role.to_s} AND right_id = " +
      "(SELECT id FROM rights WHERE controller = '#{controller.to_s}' AND rights.action = '#{action.to_s}' LIMIT 1);"
    rez = ActiveRecord::Base.connection.select_all(sql)

    if rez.count == 0 && Kernel.const_get(controller.to_s.camelize.to_s + 'Controller').new.respond_to?(action.to_s)
      new_right(controller, action, controller.capitalize + '_' + action)
      rez = ActiveRecord::Base.connection.select_all(sql)
    end

    return rez[0]['permission'].to_i if rez[0] && rez[0]['permission']

    0
  end

  # Returns whole permissions and user roles table
  def RoleRight::get_auth_list
    ActiveRecord::Base.connection.select_all('
      SELECT role_rights.id, name, controller, action, permission
      FROM role_rights
      LEFT JOIN rights ON role_rights.right_id = rights.id
      LEFT JOIN roles ON role_rights.role_id = roles.id
      ORDER BY controller, action, name;
    ')
  end

  # Adds new right and creates it coresonding enteries for each role
  def RoleRight::new_right(controller, action, description)
    rez = ActiveRecord::Base.connection.select_all("
      SELECT COUNT(*) as num FROM rights where controller = '#{controller}' AND action = '#{action}';"
    )
    if rez[0]['num'].to_i == 0
      right = Right.new(controller: controller.to_s, action: action.to_s, description: description, saved: 1)
      begin
        if right.save
          Role.all.each do |role|
            role_right = RoleRight.new(role_id: role.id, right_id: right.id)
            # 2011-03-18 [2:33:19 PM EEST] MK: tik adminui turi buti 1
            role_right.permission = (%w[admin accountant reseller user].include?(role.name.downcase) ? 1 : 0)
            role_right.save
          end
        end
      rescue => e
        MorLog.my_debug e.to_yaml
      end
    end
  end
end
