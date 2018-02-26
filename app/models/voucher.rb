# -*- encoding : utf-8 -*-
# MOR Vouchers
class Voucher < ActiveRecord::Base
  belongs_to :user
  belongs_to :payment
  belongs_to :tax, dependent: :destroy
  attr_accessible :number, :tag, :credit_with_vat, :vat_percent, :user_id, :use_date,
                  :active_till, :currency, :payment_id, :active, :tax_id
  before_destroy :v_before_destroy

  def v_before_destroy
    if is_used?
      errors.add(:active, _("Voucher_Was_Already_Used")) and return false
    end
  end

  def assign_default_tax
    self.tax = Confline.get_default_tax(0)
  end

  def get_tax
    self.assign_default_tax unless self.tax
    self.tax
  end

  def count_credit_with_vat
    self.get_tax.count_amount_without_tax(self.credit_with_vat)
  end

  def Voucher.set_tax(tax)
    Voucher.includes([:tax]).where(["user_id = -1"]).all.each { |voucher|
      voucher.tax = Tax.new unless voucher.tax
      voucher.tax.update_attributes(tax)
    }
  end

  def is_active?
    (self.use_date or self.active_till < Time.now)
  end

  def is_usable?
    self.is_active? == false and self.active.to_i == 1
  end

  def is_used?
    self.use_date
  end

  def disable_card
    current_user = User.current

    if Confline.get_value('Voucher_Card_Disable', current_user.owner_id).to_i == 1
      card = Card.where(number: number).first

      if card
        card.sold = 1
        card.first_use = Time.now

        if card.save
          Action.add_action_hash(current_user, { action: 'Disable_Card_when_Voucher_is_used', target_id: card.id,
            target_type: 'Card', data: number, data2: id })
        end
      end
    end
  end

  def Voucher.get_use_dates
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT DATE(use_date) as 'udate' FROM vouchers ORDER BY DATE(use_date) ASC")
  end

  def Voucher.get_active_tills
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT SUBSTRING(active_till,1,10) 'atill' FROM vouchers ORDER BY active_till ASC")
  end

  def Voucher.get_currencies
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT currency as 'curr' FROM vouchers ORDER BY currency ASC")
  end

  def Voucher.get_tags
    ActiveRecord::Base.connection.select_all("SELECT DISTINCT vouchers.tag FROM vouchers ORDER BY tag ASC")
  end

  def self.update_voucher(voucher, user_id, time_now, new_payment_id)
    voucher.user_id = user_id
    voucher.use_date = time_now
    voucher.payment_id = new_payment_id
    voucher.save
  end

  def make_voucher_payment(user, owner_iteration = false)
    voucher_currency = currency
    credit_without_vat = get_tax.count_amount_without_tax(credit_with_vat)

    time_now = Time.now

    credit_in_default_currency = credit_without_vat * Currency.count_exchange_rate(voucher_currency, Currency.get_default.name)
    extra_balance = credit_in_default_currency * User.current.currency.exchange_rate.to_d

    user.balance += extra_balance
    user.save

    user_id = user.id
    owner = user.owner

        calculated_tax = credit_with_vat - credit_in_default_currency

    new_payment = Payment.create(
      tax: calculated_tax,
      gross: credit_in_default_currency,
      paymenttype: 'voucher',
      amount: credit_with_vat,
      currency: voucher_currency,
      date_added: time_now,
      shipped_at: time_now,
      completed: 1,
      user_id: user_id,
      first_name: user.first_name,
      last_name: user.last_name,
      owner_id: owner.try(:id)
    )

    new_payment_id = new_payment.id

    if !owner_iteration
      self.make_voucher_payment(owner, true) if owner.id != 0
      Voucher.update_voucher(self, user_id, time_now, new_payment_id)
      self.disable_card
    end

     {
      credit_without_vat: credit_without_vat,
      credit_in_default_currency: credit_in_default_currency,
      new_payment_id: new_payment_id
    }
  end

  def is_active
    (Time.now > self.active_till || self.use_date) ? 0 : self.active
  end
end
