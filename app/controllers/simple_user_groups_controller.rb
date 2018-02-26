# -*- encoding : utf-8 -*-
# Simple Users' Groups.
class SimpleUserGroupsController < ApplicationController
  layout 'callc'

  before_filter :access_denied, if: -> { !(admin? || reseller?) }
  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :find_simple_user_group, only: [:edit, :update, :destroy]

  def list
    @page_icon, @page_title = 'group.png', _('User_Groups')
    @simple_user_groups = SimpleUserGroup.where(owner_id: corrected_user_id).where.not(id: 0).order('name asc').all
  end

  def create
    params_new_simple_user_group = params[:new_simple_user_group]
    simple_user_group = SimpleUserGroup.new(params_new_simple_user_group.merge({owner_id: corrected_user_id}))
    if simple_user_group.save
      flash[:status] = _('User_Group_successfully_created')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('User_Group_not_created'), simple_user_group)
    end
    redirect_to action: :list, new_simple_user_group: params_new_simple_user_group
  end

  def edit
    @page_icon, @page_title = 'group.png', _('Permissions')
    possible_rights = SimpleUserRight.select('name, 0 AS value, id').order(:id).all
    params_rights = params[:rights]
    if params_rights
      @rights = params_rights.map { |name, value| {name: name, value: value} }.reverse
    else
      @rights = @simple_user_group.simple_user_group_rights.
          select('simple_user_rights.name AS name, simple_user_group_rights.value AS value').
          joins('JOIN simple_user_rights ON simple_user_rights.id = simple_user_group_rights.simple_user_right_id')
    end
    @rights = possible_rights.map do |pr|
      {name: pr.name, value: @rights.select { |right| right[:name].to_s == pr.name.to_s }.first.try(:value).to_i}
    end

    @simple_user_group.assign_attributes(params[:simple_user_group])
  end

  def update
    params_simple_user_group = params[:simple_user_group]
    params_permissions = params[:permissions]
    @simple_user_group.assign_attributes(params_simple_user_group)
    if @simple_user_group.save
      @simple_user_group.update_rights(params_permissions)
      flash[:status] = _('User_Group_successfully_updated')
      redirect_to action: :list
    else
      flash_errors_for(_('User_Group_not_updated'), @simple_user_group)
      redirect_to action: :edit, id: params[:id].to_i, simple_user_group: params_simple_user_group, rights: params_permissions
    end
  end

  def destroy
    if @simple_user_group.destroy
      flash[:status] = _('User_Group_deleted')
    else
      flash_errors_for(_('User_Group_not_deleted'), @simple_user_group)
    end
    redirect_to action: :list
  end

  private

  def find_simple_user_group
    @simple_user_group = SimpleUserGroup.where(id: params[:id], owner_id: corrected_user_id).first
    if @simple_user_group.try(:id).to_i == 0
      flash[:notice] = _('User_Group_not_found')
      redirect_to(action: :list) && (return false)
    end
  end
end
