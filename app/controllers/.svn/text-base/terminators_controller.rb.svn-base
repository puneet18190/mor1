# -*- encoding : utf-8 -*-
# A Terminator is a group of Providers.
class TerminatorsController < ApplicationController
  layout 'callc'

  before_filter :check_post_method, only: [:create, :destroy, :update, :provider_remove, :provider_add]
  before_filter :check_localization
  before_filter :authorize

  @@acc_provider_view = [:list, :edit, :providers]
  @@acc_provider_edit = [:create, :update, :destroy, :provider_add, :provider_remove]
  before_filter(only: @@acc_provider_view + @@acc_provider_edit) do |method|
    allow_read, allow_edit = method.check_read_write_permission(
        @@acc_provider_view, @@acc_provider_edit, {role: 'accountant', right: :acc_manage_terminators}
    )
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  end

  before_filter :providers_enabled_for_reseller?, unless: -> { accountant? }
  before_filter :find_terminator, only: [:provider_add, :providers, :destroy, :update, :edit]

  def list
    @page_title = _('Terminators')
    @page_icon = 'provider.png'
    @terminators = corrected_current_user.load_terminators
  end

  def create
    if Terminator.create(name: params[:name].to_s, user: corrected_current_user)
      flash[:status] = _('Terminator_was_created')
    else
      flash[:notice] = _('Terminator_was_not_created')
    end

    redirect_to(action: :list) && (return false)
  end

  def destroy
    if @terminator.destroy
      flash[:status] = _('Terminator_was_destroyed')
    else
      flash_errors_for(_('Terminator_was_not_destroyed'), @terminator)
    end

    redirect_to(action: :list) && (return false)
  end

  def edit
    @page_title = "#{_('Terminator_edit')}: #{@terminator.name}"
    @page_icon = 'edit.png'
  end

  def update
    if @terminator.update_attributes(name: params[:terminator][:name])
      flash[:status] = _('Terminator_was_updated')
    else
      flash[:notice] = _('Terminator_was_not_updated')
    end

    redirect_to(action: :list) && (return false)
  end

  def providers
    @page_title = _('Terminator_providers')
    @page_icon = 'provider.png'

    @assigned, @not_assigned = @terminator.assignable_providers(corrected_current_user)
  end

  def provider_add
    provider = Provider.where(id: params[:provider_id], user_id: corrected_user_id).first

    unless provider
      flash[:notice] = _('Provider_was_not_found')
      redirect_to(action: :terminators) && (return false)
    end

    provider.terminator = @terminator

    if provider.save
      flash[:status] = _('Provider_was_assigned')
    else
      flash[:notice] = _('Provider_was_not_assigned')
    end

    redirect_to(action: :providers, id: params[:id]) && (return false)
  end

  def provider_remove
    provider = Provider.where('id = ? AND (user_id = ? OR common_use = 1)', params[:provider_id], corrected_user_id).first

    unless provider
      flash[:notice] = _('Provider_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    provider.terminator = nil

    if provider.save
      flash[:status] = _('Provider_was_removed_from_terminator')
    else
      flash[:notice] = _('Provider_was_not_removed_from_terminator')
    end

    redirect_to(action: :providers, id: params[:id]) && (return false)
  end

  private

  def find_terminator
    @terminator = corrected_current_user.load_terminator(params[:id])

    unless @terminator
      flash[:notice] = _('Terminator_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end
end
