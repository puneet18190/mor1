# -*- encoding : utf-8 -*-
class Invoicedetail < ActiveRecord::Base
  attr_accessible :id, :invoice_id, :name, :quantity, :price, :invdet_type, :prefix, :total_time

  belongs_to :invoice

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    user = User.current.blank? ? User.where(id: 0).first : User.current
    b.to_d * user.currency.exchange_rate.to_d
  end

  # coconverted_price(exr)nverted attributes for user in given currency exrate
  def converted_price(exr)
    b = read_attribute(:price)
    b.to_d * exr.to_d
  end

  def nice_inv_name
    id_name=""
    if  name.to_s.strip[-1..-1].to_s.strip == "-"
      name_length = name.strip.length
      name_length = name_length.to_i - 2
      id_name = name.strip
      id_name = id_name[0..name_length].to_s
    else
      id_name = name.to_s.strip
    end
    id_name.to_s.strip
  end

  def self.invoice_details_order_by(options, fpage, items_per_page)
    order_by, order_desc = [options[:order_by], options[:order_desc]]

    if !order_by.blank? && !order_desc.blank? && Invoicedetail.accessible_attributes.member?(order_by)
      order_desc = order_desc.to_i.zero? ? 'ASC' : 'DESC'
      order_string = "#{order_by} #{order_desc}"
      order_string += ", prefix #{order_desc}" if order_by == 'name'
    else
      order_string = "name ASC, prefix ASC"
    end

    selection_count = Invoicedetail.limit("#{fpage}, #{items_per_page}").count
    selection = Invoicedetail.order(order_string).limit("#{fpage}, #{items_per_page}").all
    [selection_count, selection]
  end

  def self.invoice_details_filter(options, invoice_id)
    where = Invoicedetail.where_conditions(options)
    clear_search = !where.blank?
    selection = Invoicedetail.where(where).where(invoice_id: invoice_id)

    [selection, clear_search]
  end

  def self.reset_destination_number
    @@destination_number = 0
  end

  def destination_number
    "#{@@destination_number += 1}."
  end

  private

  def self.where_conditions(options)
    prefix = options[:s_prefix]
    where = prefix.present? ? "prefix LIKE #{ActiveRecord::Base::sanitize(prefix)}" : []

    where
  end
end
