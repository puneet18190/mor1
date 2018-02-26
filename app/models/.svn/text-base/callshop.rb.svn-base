# -*- encoding : utf-8 -*-
# A callshop is a business that physically provides phones for the purpose of making long-distance telephone calls.
class Callshop < ActiveRecord::Base
  extend UniversalHelpers

  has_many :invoices, class_name: 'CsInvoice'
  has_many :unpaid_invoices, -> { where(paid: false) }, class_name: 'CsInvoice'
  has_and_belongs_to_many :users, -> { order('usergroups.position asc') },
                          join_table: 'usergroups', foreign_key: 'group_id' # should be has many through :|

  def self.table_name()
    'groups'
  end

  def free_booths_count
    # all users in callshop - unpaid (reserved or occupied) booths
    users.size - invoices.where(['paid_at IS NULL']).size
  end

  def status
    calls = 0
    {
        free_booths: free_booths_count,
        booths: users.inject([]) do |booths, user|
          user_cs_invoice = user.cs_invoices.first
          created_at = user_cs_invoice.try(:created_at).try(:strftime, '%Y-%m-%d %H:%M:%S')
          invoice_comment = user_cs_invoice.try(:comment)
          invoice_type = user_cs_invoice.try(:invoice_type)
          user_timestamp = stamp(user)
          user_booth_balance = booth_balance(user)

          booth = {id: user.id, element: nil, state: user.booth_status, number: nil, duration: nil, country: nil,
                   user_rate: nil, local_state: false, comment: nil, created_at: nil, balance: nil, timestamp: nil}

          case booth[:state]
            when 'free'
              booth
            when 'reserved'
              booth.merge!({
                               comment: invoice_comment,
                               created_at: created_at,
                               balance: user_booth_balance,
                               timestamp: user_timestamp,
                               user_type: invoice_type,
                               server: '',
                               channel: ''
                           })
            when 'occupied'
              calls += 1
              active_call = user.activecalls.first
              destination = active_call.try(:destination)

              booth.merge!({
                               comment: invoice_comment,
                               created_at: created_at,
                               balance: user_booth_balance,
                               country: destination.try(:direction).try(:name),
                               number: active_call.try(:dst),
                               channel: active_call.try(:channel),
                               user_type: invoice_type,
                               server: active_call.try(:server_id),
                               user_rate: active_call.try(:user_rate),
                               # The UniversalHelpers should be split and grouped into smaller ones, since currently,
                               #   instance methods can't reach the helper's class methods and class methods can't
                               #   reach instance methods.
                               duration: Callshop.nice_time(active_call.try(:duration)),
                               timestamp: user_timestamp
                           })
          end

          booths.push(booth)
        end,
        active_calls: calls
    }
  end

  def self.reserve_booth(invoice, params)
    user = invoice.user
    if user.present?
      old_invoice = user.try(:cs_invoices).first
      unless old_invoice
        tax = user.get_tax.dup
        tax.save
        invoice.tax_id = tax.id
        invoice.balance_with_tax = params[:invoice][:balance].to_d
        invoice.save
        user_type = (params[:invoice][:invoice_type].to_s == "postpaid" ? 1 : 0)
        balance = (user_type == 1 ? 0 : invoice.balance_with_tax)
        if params[:add_with_tax_new].to_i == 1 && invoice.tax
          balance = invoice.tax.count_amount_without_tax(balance).to_d
          invoice.balance_with_tax = invoice.balance_with_tax
          invoice.balance = balance
          invoice.save
        else
          invoice.balance_with_tax = invoice.tax.apply_tax(balance)
          invoice.save
        end
        user.update_attributes({balance: balance, postpaid: user_type, blocked: 0})
      end
    end

    return user, old_invoice, invoice
  end

  def self.update(invoice, params)
    user, invoice_tax, params_invoice = invoice.user, invoice.tax, params[:invoice]
    balance = params_invoice[:balance]
    balance = 0 if invoice.balance - balance.to_d <= 0 if params[:increase].to_s != 'true' # so it won't get negative

    if params[:add_with_tax].to_i == 1 && invoice_tax
      params_invoice[:balance_with_tax] = balance.to_d
      balance = invoice_tax.count_amount_without_tax(balance).to_d
    else
      params_invoice[:balance_with_tax] = invoice_tax.apply_tax(balance).to_d if invoice_tax
    end

    invoice.update_attributes(params_invoice)
    user.update_attributes(balance: balance.to_d) if balance

    return user, invoice
  end

  def self.topup_update(invoice, params)
    user = invoice.user
    balance = params[:invoice][:balance]
    if params[:add_with_tax].to_i == 1 && invoice.tax
      balance = round_to_cents(invoice.tax.count_amount_without_tax(balance).to_d).to_d
    end

    balance_with_tax = params[:invoice][:balance_with_tax].to_d

    if params[:increase] == "true"
      logger.debug " >> Increasing balance by #{balance}"
      user.balance += balance
      invoice.balance += balance
      invoice.balance_with_tax += balance_with_tax
    else
      logger.debug " >> Decreasing balance by #{balance}"
      user.balance -= balance
      invoice.balance -= balance
      invoice.balance_with_tax -= balance_with_tax
    end

    user.balance = invoice.balance = invoice.balance_with_tax = 0 if user.balance < 0
    user.save
    invoice.save

    return user, invoice
  end

  def simple_session?
    self.simple_session.to_i == 1
  end

  def nice_type
    case postpaid.to_i
    when 1
      'postpaid'
    when 0
      'prepaid'
    else
      ''
    end
  end

  private

  def stamp(booth)
    stamps = []
    booth_cs_invoices = booth.cs_invoices

    if booth_cs_invoices.any?
      invoice = booth_cs_invoices.first
      calls = booth.activecalls_since(invoice.created_at)
      if calls.size > 0
        calls_start_time = calls[0]
        stamps.push(calls_start_time.try(:start_time).to_i) if calls_start_time
      end
      stamps.push(invoice.updated_at.to_i)
    else
      nil
    end
    stamps.max
  end

  def booth_balance(booth)
    booth_cs_invoices = booth.cs_invoices

    if booth_cs_invoices.any?
      invoice = booth_cs_invoices.first
      invoice_call_price = invoice.call_price

      if invoice.postpaid?
        -1 * invoice_call_price
      else # prepaid
        invoice.balance - invoice_call_price
      end
    else
      nil
    end
  end
end
