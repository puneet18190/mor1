# -*- encoding : utf-8 -*-
module PaymentsHelper
  include Paypal::Helpers
  include WebMoney::Helpers
  include Linkpoint::Helpers
  include Cyberplat::Helpers
  include Ouroboros::Helpers

  def payments_clear_search_on
    now = Time.now
    year_from, month_from, day_from = (session[:year_from] || now.year).to_i, (session[:month_from] || now.month).to_i, (session[:day_from] || now.day).to_i
    year_till, month_till, day_till = (session[:year_till] || now.year).to_i, (session[:month_till] || now.month).to_i, (session[:day_till] || now.day).to_i

    date_from = DateTime.new(year_from, month_from, day_from, 0, 0, 0).strftime('%Y-%m-%d %H:%M:%S')
    date_till = DateTime.new(year_till, month_till, day_till, 23, 59, 59).strftime('%Y-%m-%d %H:%M:%S')
    user_date_from = Time.current.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
    user_date_till = Time.current.end_of_day.strftime('%Y-%m-%d %H:%M:%S')

    return (date_from != user_date_from || date_till != user_date_till || @clear.to_i == 1)
  end

  def find_user_and_card(payment_user_id)
    user = User.where(id: payment_user_id).first
    card = Card.where(id: payment_user_id).first

    return user, card
  end

  def hide_non_completed_payments_for_user
    Confline.get_value('Hide_non_completed_payments_for_user', 0).to_i
  end

  def hide_uncompleted_payment(payment, hide_uncompleted_payment)
    return (
    hide_uncompleted_payment == 1 &&
        (payment.pending_reason == 'Unnotified payment' || !payment.pending_reason) &&
        payment.paymenttype.to_s != 'manual'
    )
  end

  def payment_pending_reason(payment)
    return !payment.completed? && (['Unnotified payment', 'Waiting for confirmation'].include?(payment.pending_reason))
  end
end
