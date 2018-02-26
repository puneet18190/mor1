# -*- encoding : utf-8 -*-
# Common Use Providers.
class CommonUseProvidersController < ApplicationController
  layout 'callc'

  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_data, only: [:edit, :update, :destroy]
  before_filter :find_cup_reseller, only: [:rs_edit, :rs_update]

  def index
    @page_title, @page_icon = _('Common_use_providers'), 'provider.png'

    @options = session[:common_use_providers_list_options] || {}

    # Page number is an exception because it defaults to 1
    @options[:page] = if params[:page].to_i > 0
                        params[:page].to_i
                      elsif @options[:page].to_i <= 0
                        1
                      else
                        @options[:page]
                      end


    @options[:order_by] = if params[:order_by]
                              params[:order_by].to_s
                            elsif !@options[:order_by]
                              'id'
                            else
                              @options[:order_by]
                            end

    @options[:order_desc] = if params[:order_desc]
                              params[:order_desc].to_i
                            elsif !@options[:order_desc]
                              0
                            else
                              @options[:order_desc]
                            end

    order_by = if !@options[:order_by]
                 ' '
               else
                 "ORDER BY #{@options[:order_by]} #{@options[:order_desc] == 0 ? 'asc' : 'desc'}"
               end

    @fpage, @total_pages, @options = Application.pages_validator(session, @options, CommonUseProvider.count)

    limit = " LIMIT #{@fpage}, #{session[:items_per_page].to_i}"

    # Select records, common use providers, resellers pro, retail and wholesale tariffs
    @data = CommonUseProvider.find_by_sql("SELECT common_use_providers.id,  concat(providers.name,' ', providers.tech,'/', providers.server_ip, ':',providers.port) as provider_name,tariffs.name as tariff_name, #{SqlExport.nice_user_sql} from common_use_providers LEFT JOIN users ON (users.id = common_use_providers.reseller_id) LEFT JOIN providers ON (providers.id = common_use_providers.provider_id) LEFT JOIN tariffs ON (tariffs.id = common_use_providers.tariff_id) #{order_by} #{limit}")

    @common_use_providers = Provider.where(common_use: 1).order(:name)
    @resellers = User.select("users.*, #{SqlExport.nice_user_sql}").where(usertype: :reseller, own_providers: 1)
    @resellers = reseller_pro_active? ? @resellers.order('nice_user ASC') : @resellers.limit(1)
    @tariffs = Tariff.where.not(purpose: 'provider').where(owner_id: 0).order(:purpose, :name)

    session[:common_use_providers_list_options] = @options
  end

  def create
    select_reseller, select_provider, select_tariff =
        params[:select_reseller].to_i, params[:select_provider].to_i, params[:select_tariff].to_i

    if select_provider != 0 && select_reseller != 0 && select_tariff != 0

      # check record, must not be duplicate
      if check_record(select_reseller, select_provider)
        flash[:notice] = _('Record_exists')
      else
        data = CommonUseProvider.new({provider_id: select_provider,
                                      reseller_id: select_reseller,
                                      tariff_id: select_tariff}
        )
        data.save
        flash[:status] = _('Record_created')
      end
    else
      flash[:notice] = _('You_must_select_all_three_parameters')
    end

    redirect_to(action: :index)
  end

  def edit
    @page_title, @page_icon = _('Common_use_providers_edit'), 'edit.png'

    @data = @common_use_provider
    @common_use_providers = Provider.where(common_use: 1).order(:name)
    @resellers = User.select("users.*, #{SqlExport.nice_user_sql}").
        where(usertype: :reseller, own_providers: 1).order('nice_user ASC')
    @tariffs = Tariff.where.not(purpose: 'provider').where(owner_id: 0).order(:purpose, :name)
  end

  def update
    select_reseller, select_provider, select_tariff, id =
        params[:select_reseller], params[:select_provider], params[:select_tariff], params[:id].to_i

    # check record, must not be duplicate
    if check_record(select_reseller, select_provider, id)
      flash[:notice] = _('Record_exists')
      redirect_to(action: :edit, id: id)
    else
      data = @common_use_provider
      data.update_attributes(reseller_id: select_reseller, provider_id: select_provider, tariff_id: select_tariff)
      flash[:status] = _('Record_updated')
      redirect_to(action: :index)
    end
  end

  def destroy
    data = @common_use_provider
    data.destroy ? flash[:status] = _('Record_deleted') : flash[:notice] = _('Record_not_deleted')
    redirect_to(action: :index)
  end

  def let_resellers_use_all_common_use_providers
    if admin?
      providers = Provider.where(common_use: 1, user_id: 0).order(:name)
      resellers = User.where(usertype: :reseller, own_providers: 1)

      if resellers && providers
        resellers.each do |reseller|
          # for reseller add all common use providers with default resellers tariff
          providers.each do |provider|
            reseller_id, provider_id, tariff_id = reseller.id, provider.id, reseller.tariff.id
            if !check_record(reseller_id, provider_id)
              CommonUseProvider.create({provider_id: provider_id, reseller_id: reseller_id, tariff_id: tariff_id})
            end
          end
        end
      end

      flash[:status] = _('Record_created')
      redirect_to(action: :index)
    else
      dont_be_so_smart
      redirect_to :root
    end
  end

  def rs_edit
    @page_title = _('Provider_edit')
    @page_icon = 'edit.png'
  end

  def rs_update
    @page_title = _('Provider_edit')
    @page_icon = 'edit.png'

    @common_use_provider.update_attributes(provider_name: params[:provider_name].to_s.strip)
    flash[:status] = _('Provider_was_successfully_updated')
    redirect_to(controller: :providers, action: :list)
  end

  private

  def check_record(reseller, provider, id = nil)
    # For update with no changes
    CommonUseProvider.where(reseller_id: reseller, provider_id: provider).where(id ? "id != #{id}" : '').first.present?
  end

  def find_data
    if !(@common_use_provider = CommonUseProvider.where(id: params[:id]).first)
      flash[:notice] = _('Common_Use_Provider_not_found')
      redirect_to(action: :index)
    end
  end

  def find_cup_reseller
    @common_use_provider = CommonUseProvider.where(provider_id: params[:id], reseller_id: current_user_id).first
    if @common_use_provider.blank?
      flash[:notice] = _('Common_Use_Provider_not_found')
      redirect_to(controller: :providers, action: :list)
    end
  end
end
