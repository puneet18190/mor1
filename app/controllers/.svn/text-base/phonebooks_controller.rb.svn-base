# -*- encoding : utf-8 -*-
# Organized list of known CallerIDs.
class PhonebooksController < ApplicationController
  WIKI_HELP_LINK = 'http://wiki.kolmisoft.com/index.php/PhoneBook'
  layout 'callc'

  before_filter :access_denied, only: [:list, :add_new, :edit, :destroy], if: -> { !(user? || admin?) }
  before_filter :check_pbx_addon, only: [:list, :edit]
  before_filter :authorize
  before_filter :check_post_method, only: [:destroy, :update]
  before_filter :check_localization
  before_filter :find_phonebook, only: [:update, :edit, :destroy]
  before_filter :new_phonebook, only: [:list, :add_new]

  def list
    @page_title = _('PhoneBook')
    @page_icon = 'book.png'
    @help_link = WIKI_HELP_LINK

    @phonebooks = Phonebook.user_phonebooks(current_user)
  end

  def add_new
    @phonebook.assign_attributes(added: Time.now, user: current_user)

    if @phonebook.valid? && @phonebook.save
      flash[:status] = _('record_successfully_added')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Please_fill_all_fields'), @phonebook)
      redirect_to(action: :list, phonebook: params[:phonebook])
    end
  end

  def edit
    @page_title = _('Edit_PhoneBook')
    @page_icon = 'edit.png'
    @help_link = WIKI_HELP_LINK
  end

  def update
    if @phonebook.update_attributes(params[:phonebook])
      flash[:status] = _('record_successfully_updated')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Record_was_not_saved'), @phonebook)
      redirect_to(action: :edit, id: @phonebook)
    end
  end

  def destroy
    @phonebook.destroy
    flash[:status] = _('record_successfully_deleted')
    redirect_to(action: :list)
  end

  private

  def find_phonebook
    @phonebook = Phonebook.where(id: params[:id], user_id: current_user_id).first

    unless @phonebook
      flash[:notice] = _('Record_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def new_phonebook
    @phonebook = Phonebook.new(params[:phonebook])
  end

  def check_pbx_addon
    unless pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end
end
