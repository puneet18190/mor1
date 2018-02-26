# -*- encoding : utf-8 -*-
class Service < ActiveRecord::Base
  attr_protected
  has_many :subscriptions
  has_many :flatrate_destinations, :dependent => :destroy

  validates :name,
          presence: {
            message: _('Service_must_have_a_name'),
            on: :create
        }
  validates :servicetype,
          presence: {
            message: _('Service_must_have_a_service_type'),
            on: :create
          },
          format: {
            with: /\A(periodic_fee|one_time_fee|flat_rate|dynamic_flat_rate| *)\z/,
            message: _('Service_type_invalid')
          }
  validates :quantity,
          presence: {
            message: _('Service_must_have_quantity'),
            if: -> { ['flat_rate', 'dynamic_flat_rate'].include?(servicetype) }
          },
          numericality: {
            message: _('Quantity_must_be_numeric'),
            if: -> { ['flat_rate', 'dynamic_flat_rate'].include?(servicetype) }
          },
          format: {
            :with => /\A[1-9][0-9]*\z/,
            :message => _('Quantity_must_be_greater_than_zero'),
            if: -> { ['flat_rate', 'dynamic_flat_rate'].include?(servicetype) }
          }
  validates :round_by,
          numericality: {
            message: _('Round_by_must_be_positive'),
            if: -> { ['flat_rate', 'dynamic_flat_rate'].include?(servicetype) },
            greater_than_or_equal_to: 0
          }



  after_validation :service_period_validation, :service_quantity_validation

  before_destroy :s_before_destroy

  def s_before_destroy
    if subscriptions.size > 0
      errors.add(:subscriptions, _('Cant_delete_subscriptions_exist'))
      return false
    end
    return true
  end

  def type
    return servicetype
  end

  # converted attributes for user in current user currency
  def price
    current_user = User.current
    total_price = read_attribute(:price)
    if current_user && current_user.currency
      total_price.to_d * current_user.currency.exchange_rate.to_d
    else
      total_price
    end
  end

  def price= value
    current_user = User.current
    if current_user && current_user.currency
      total_value = (value.to_d / current_user.currency.exchange_rate.to_d).to_d
    else
      total_value = value
    end
    write_attribute(:price, total_value)
  end

  # converted attributes for user in current user currency
  def selfcost_price
    total_price = read_attribute(:selfcost_price)
    if User.current && User.current.currency
      total_price.to_d * User.current.currency.exchange_rate.to_d
    else
      total_price
    end
  end

  def selfcost_price= value
    if User.current && User.current.currency
      total_price = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      total_price = value
    end
    write_attribute(:selfcost_price, total_price)
  end

  def service_period_validation
    if servicetype != 'periodic_fee' || !(self.periodtype.to_s =~ /^(day|month)$/)
      self.periodtype = 'month'
    end
  end

  def service_quantity_validation
    if !['flat_rate', 'dynamic_flat_rate'].include?(servicetype)
      self.quantity = 1
    end
  end

  def price_validation(params)
    params_price = params[:price]
    params_selfcost_price = params[:selfcost_price]
    unless (params_price =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/) || params_price.blank?
      self.errors.add(:price, _('Service_Price_numeric'))
    end
    unless (params_selfcost_price =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/) || params_selfcost_price.blank?
      self.errors.add(:selfcost_price, _('Service_Self_cost_numeric'))
    end

    self.errors.size == 0
  end

  def valid_by_params?(params = nil)

    price_validation(params) if params
    if self.errors.size > 0
      pre_save_errors = self.errors.dup
    end
    self.valid?
    if pre_save_errors.present?
      pre_save_errors.each do |key, message|
        self.errors.add(key, message)
      end
    end
    self.errors.empty?
  end

  def current_user_is_owner?
    current_user = User.current
    unless current_user.is_admin?
      current_user.is_accountant? ? (owner_id == 0) : (owner_id == current_user.id)
    else
      true
    end
  end

  def update_by_params(new_service_params)
    params = new_service_params.reject{ |_key, value| value.blank? }
    self.price_validation(params)
    self.assign_attributes(params)
  end

  def update_if_params_valid(params)
    self.update_attributes(params) if price_validation(params)
  end
end
