# -*- encoding : utf-8 -*-
class Invoice < ActiveRecord::Base

  attr_protected

  belongs_to :user
  belongs_to :payment
  has_many :invoicedetails, :dependent => :destroy
  belongs_to :tax, :dependent => :destroy

  before_destroy :check_send

  after_destroy :increase_user_balance

  include SqlExport
  include UniversalHelpers
  require 'pdf_gen/prawn'


  def check_send
    if invoice_was_send?
      errors.add(:send, _('Cannot_delete_Invoice_that_was_send'))
      return false
    end
  end

  def increase_user_balance
    # we should _decrease_ user's balance by payments amount, because it is deleted and user should owe more (because there are no payment)
    user = self.user
    payment = self.payment
    if payment
      user.balance -= payment.amount / self.invoice_exchange_rate.to_d
      user.save
      payment.destroy
    end
    Action.add_action(User.current.id, "invoice_deleted", user.id.to_s)
  end

  def invoice_was_send?(conf = Confline.get_value("Invoice_allow_recalculate_after_send").to_i )
    (sent_email == 1 or sent_manually == 1) and  conf == 0
  end

  def price_with_tax(options = {})
    if options[:ex]
      if tax
        tax.apply_tax(converted_price(options[:ex]), options)
      else
        if options[:precision]
          format("%.#{options[:precision].to_i}f", converted_price_with_vat(options[:ex])).to_d
        else
          converted_price_with_vat(options[:ex])
        end
      end

    else
      if tax
        tax.apply_tax(price, options)
      else
        if options[:precision]
          format("%.#{options[:precision].to_i}f", price_with_vat).to_d
        else
          price_with_vat
        end
      end
    end
  end

  def tax_amount(options ={})
    if options[:ex]
      tax.count_tax_amount(converted_price(options[:ex]), options)
    else
      tax.count_tax_amount(price, options)
    end
  end

  def calls_price
    price = 0.0
    self.invoicedetails.each do |invd|
      price += invd.price if invd.invdet_type == 0
    end
    price
  end

  def filename(type, file_type, prefix = nil, dc = nil)
    file_prefix = prefix || 'Invoice'
    dc_string = (dc.present?) ? "-#{dc}" : ''
    long_name = self.user.first_name.present? || self.user.last_name.present? ? "#{file_prefix}-#{self.user.first_name}_#{self.user.last_name}-#{self.user_id}-#{self.number}-#{self.issue_date}#{dc_string}" : "#{file_prefix}-#{self.user.username}-#{self.user_id}-#{self.number}-#{self.issue_date}#{dc_string}"
    temp = (type == "prepaid" ? "Prepaid_" : "")
    use_short = Confline.get_value("#{temp}Invoice_Short_File_Name", user.owner_id).to_i
    use_short == 1 ? "#{user.first_name}_#{user.last_name}.#{file_type}" : "#{long_name}.#{file_type}"
  end

  def paid?;
    paid == 1;
  end

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    currency = User.current.currency
    if currency.name == invoice_currency.to_s
      b.to_d * invoice_exchange_rate.to_d
    else
      b.to_d * currency.exchange_rate.to_d
    end
  end

  def price_with_vat
    b = read_attribute(:price_with_vat)
    currency = User.current.currency
    if currency.name == invoice_currency.to_s
      b.to_d * invoice_exchange_rate.to_d
    else
      b.to_d * currency.exchange_rate.to_d
    end
  end

  # converted attributes for user in given currency exrate
  def converted_price(exr)
    b = read_attribute(:price)
    b.to_d * exr.to_d
  end

  # converted attributes for user in given currency exrate
  def converted_price_with_vat(exr)
    b = read_attribute(:price_with_vat)
    b.to_d * exr.to_d
  end

    # converted attributes for user in given currency exrate
  def raw_price
    read_attribute(:price)
  end

  # converted attributes for user in given currency exrate
  def raw_price_with_vat
    read_attribute(:price_with_vat)
  end

  # xslx Is generated Directly from object values, so exchange rates have to be set before passing object to generator
  # New object is created, just in case somebody tries to save changes to this object
  def copy_for_xslx
    invoice = self
    invoicedetails = self.invoicedetails_grouped_calls_by_destination

    return invoice, invoicedetails
  end

  # Calls will be grouped depending on Confline setting
  def invoicedetails_grouped_calls_by_destination
    type = (user.postpaid.to_i == 1 || self.user.owner_id != 0) ? 'postpaid' : 'prepaid'
    temp = (type == 'prepaid' ? 'Prepaid_' : '')
    group_by_subscription = Confline.get_value("#{temp}Group_Simple_Invoice_Subscriptions", user.owner_id).to_i == 1
    group_by_destination = Confline.get_value('group_regular_calls_by_destination', self.user.try(:owner).try(:id).to_i).to_i == 1

    if group_by_subscription && group_by_destination
      return grouped_by_destination_and_service
    elsif group_by_subscription
      return invoicedetails_grouped
    elsif group_by_destination
      return self.invoicedetails
    else
      return invoicedetails_ordered
    end
  end

=begin
  List of invoice financial data grouped by tryer status. should not be coding
  application logic to query(IF(paid=...)), but since i dont like db structure the way it is..

  *Params*
  +owner_id+ owner of users that the user is interested in, but might be nil if
     current user if ordinary user
  +user_id+ user that has invoices generated for him, might be nil if admin,
     reseller or accountatn is not interested i certain user, but interested in all his users.
     BUT IF we are generating financial statemens for ordinary users, they cannot see other users
     information and must supply theyr own id
  +status+ valid status parameter would be 'paid' 'unpaid' or 'all', might be nil
     in that case all statuses would be selected
  +from_date, till_date+ dates as strings
  +ordinary_user+ if user is of type 'user' there is no need to join users table, but user_id mus
     be specified.

  *Returns*
  +invoices+ array or smht iterable of Invoice instances, that has count, price,
   price_with_vat and paid methods
=end
  def self.financial_statements(owner_id, user_id, status, from_date, till_date, ordinary_user=true)
    #if user not is of type 'user' he must supply user_id. or else invalid params are supplied
    if ordinary_user and not user_id
      raise "invalid parameters, 'user' must supply his own id"
    end

    condition = ["issue_date BETWEEN '#{from_date}' AND '#{till_date}'"]
    join = "JOIN taxes ON taxes.id = invoices.tax_id "
    if not ordinary_user
      join << "JOIN users ON users.id = invoices.user_id"
      condition << "owner_id = #{owner_id}"
    end
    condition << "user_id = #{user_id}" if user_id.present? && user_id != 'all' && user_id.to_i != -2
    if status != 'all' and ['paid', 'unpaid'].include? status
      condition << "paid = #{status == 'paid' ? 1 : 0}"
    end

    Struct.new('We', :count, :price, :price_with_vat, :status)
    paid = Struct::We.new(0, 0, 0, 'paid')
    unpaid = Struct::We.new(0, 0, 0, 'unpaid')

    invoices = Invoice.joins(join).where(condition.join(" AND ")).all
    if invoices.size > 0
      invoices.each do |invoice|
        if invoice.paid?
          paid.price_with_vat += invoice.price_with_tax
          paid.price += invoice.price
          paid.count += 1
        else
          unpaid.price_with_vat += invoice.price_with_tax
          unpaid.price += invoice.price
          unpaid.count += 1
        end
      end
    end
    return paid, unpaid

    invoices = Invoice.find_by_sql(query)
  end

  #================================== PDF generation ===================================================================

  def generate_simple_pdf(current_user, dc, nc, cde, gde, show_avg_rate, testing_mode = false)
    ex = self.invoice_exchange_rate
    user = self.user
    prepaid, prep = self.new_invoice_type(user)
    type = (user.postpaid.to_i == 1 || self.user.owner_id != 0) ? 'postpaid' : 'prepaid'
    company = Confline.get_value('Company', user.owner_id)
    nice_number_hash = { change_decimal: cde, global_decimal: gde, nc: nc }
    options = self.genereate_options(current_user, ex)

    temp = (type == "prepaid" ? "Prepaid_" : "")
    group = Confline.get_value("#{temp}Group_Simple_Invoice_Subscriptions", user.owner_id).to_i
    group == 1 ? invoicedetails = invoicedetails_grouped : invoicedetails = invoicedetails_ordered

    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf = PdfGen::Generate.invoice_header_pdf(self, pdf, company, dc)
    items = []

    # Grouped into Calls
    invoicedetails.each do |invoicedetail|
      if invoicedetail.prefix.present? || invoicedetail.prefix != ''
        items << ['Calls', {text: self.nice_invoice_number((invoicedetail.price * ex), nice_number_hash).to_s, align: :right}]
      else
        items << [
          invoicedetail.nice_inv_name,
          {text: self.nice_invoice_number(((invoicedetail.invdet_type > 0 && invoicedetail.name != 'Calls') ? invoicedetail.quantity * invoicedetail.converted_price(ex) : invoicedetail.converted_price(ex)), nice_number_hash).to_s, align: :right}
       ]
      end
    end

    # first page max 19 rows
    # others 31 rows
    # n - number of empty rows
    # x - number of required rows
    if items.size <= 16
      empty_rows_number = 16 - items.size
      empty_rows_number -= self.tax ? self.tax.applied_tax_list(self.converted_price(ex), :precision => nc).size : 1
      empty_rows_number -= 1 if user.minimal_charge_enabled?
      empty_rows_number += 3 if empty_rows_number < 0
      (empty_rows_number-4).times { items << [' ', ''] } if empty_rows_number > 4
    elsif items.size == 18
      4.times { items << [' ', ''] }
    elsif 26 <= ((items.size - 22) % 31)
      empty_rows_number = 31 - ((items.size - 22) % 31)
      empty_rows_number.times { items << [' ', ''] }
    end

    items << [{:text => _('Minimal_Charge_for_Calls') + " (#{dc})", :background_color => "FFFFFF", :colspan => 1, :align => :right, :borders => [:top]}, {:text => self.nice_invoice_number(user.converted_minimal_charge(ex).to_d, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}] if user.minimal_charge_enabled?
    items << [{:text => _('SUBTOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 1, :align => :right, :borders => (user.minimal_charge_enabled? ? [] : [:top])}, {:text => self.nice_invoice_number(self.converted_price(ex).to_d, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]

    items_t, up_string, tax_amount, price_with_tax = tax_items(ex, nc, nice_number_hash, 1, dc)
    items += items_t
    items << [{:text => _('TOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 1, :align => :right, :border_width => 0}, {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    # Balance Line functionality from 12.126
    if Confline.get_value("#{prepaid}Invoice_Show_Balance_Line", user.owner_id).to_i == 1 and (Confline.get_value("Show_balance_line_setting").to_i == 1 or Confline.get_value("Show_balance_line_setting").blank?)
      balance = owned_balance_from_previous_month
      to_pay = price_with_tax
      to_pay += balance[1].to_f if balance
      items << [{text: _('total_amount_due') + " (#{dc})", :background_color => "FFFFFF", :colspan => 1, :align => :right, :border_width => 0}, {:text => self.nice_invoice_number(to_pay, nice_number_hash).to_s, :colspan => 1, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    end

    pdf.table(items,
              :row_colors => ["FFFFFF", "DDDDDD"], :width => 550,
              :font_size => 10,
              :headers => [_('Service'), _('Total') + " (#{dc})"],
              :align_headers => {0 => :left, 1 => :right,},
              :column_widths => {0 => 450}) do
      column(0).style(:align => :left, :height => 15, :width => 450)
      column(1).style(:align => :right, :height => 15)
      column(2).style(:align => :right, :height => 15)
      column(3).style(:align => :right, :height => 15)
      column(4).style(:align => :right, :height => 15)
      column(5).style(:align => :right, :height => 15)
    end

    #    if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
    #      pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id), {:page=>page+1, :pages=>pages})
    #    end

    pdf.bounding_box([0, pdf.cursor + up_string],
                     :width => 450) do
      pdf = PdfGen::Generate.invoice_footer_pdf(pdf, self, {:show_end_title => true})
    end

    pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 12], :width => pdf.bounds.width do
      pdf.text Confline.get_value("#{prepaid}Invoice_End_Title", user.owner), :size => 12, :align => :center
    end

    pdf = pdf_end(pdf, options)

    test_return = testing_mode ? items : []
    return pdf, test_return
  end

  def generate_invoice_detailed_pdf(current_user, dc, nc, cde, gde, show_avg_rate, testing_mode = false)
    ex = self.invoice_exchange_rate
    nice_number_hash = { change_decimal: cde, global_decimal: gde, nc: nc}

    options = self.genereate_options(current_user, ex)
    user = options[:user]
    type = (self.user.postpaid.to_i == 1 or self.user.owner_id != 0) ? '' : "Prepaid_"
    user_id = current_user.is_reseller? ? current_user.id : user.owner
    # if page limit isnt set, default is 20
    limit = Confline.get_value("#{type}Invoice_page_limit", user_id).to_i ? Confline.get_value("#{type}Invoice_page_limit", user_id).to_i : 20
    max_limit = Confline.get_value("Max_PDF_pages").to_i
    limit = max_limit if limit > max_limit && max_limit > 0
    hide_dst = hide_pdf_dst?(user)
    # 24 rows first page, 31 rows every other page and 7 rows reserved for totals(calculated manually)
    page_limit = 10 + (31 * (limit - 1)) - 1
    page_limit_error = 0
    prepaid = invoice_type == 'prepaid' ? "#{invoice_type.capitalize}_" : ''

    ###### Generate PDF ########
    pdf = Prawn::Document.new(size: 'A4', layout: :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf = PdfGen::Generate.invoice_header_pdf(self, pdf, options[:company], current_user.currency.name)
    items = []

    total_time = 0
    total_price = 0
    total_calls = 0

    invoicedetails.order(:name).each do |item|
      if (item.invdet_type > 0 || item.name == _("Did_owner_cost") || item.name == _("SMS")) && item.name != 'Calls'
        ii = []
        ii << item.nice_inv_name
        ii << ''

        if item.name == _("Did_owner_cost")
          ii << {text: nice_time(item.total_time, options[:min_type]).to_s, align: :center}
        else
          ii << ''
        end

        if options[:show_avg_rate] == 1
          ii << ' '
        end
        if item.invdet_type > 0
          ii << {text: nice_invoice_number((item.quantity * item.converted_price(ex)), nice_number_hash).to_s, align: :right}
        else
          ii << {text: nice_invoice_number((item.converted_price(ex)), nice_number_hash).to_s, align: :right}
          total_calls += item.quantity
          total_time += item.total_time.to_i
        end
        items << ii
        break if items.size >= page_limit
      end
    end
    dgids = []

    calls, r_calls = self.direction_calls(options)# generates sql for invoice content
    # prints content of invoice detailed pdf table

    # Nepamirst Surefactorint Sito. Du ciklai darantys lygiai ta pati.
    calls.each do |item|
      ii = []
      dg_dest_names = item['dg_name'].to_s
      if !item['dest_name'].blank?
        dg_dest_names += " - " + item['dest_name'].to_s
      end
      if !item['to_did'].blank?
        dg_dest_names = _('Calls_To_Dids')
      end

      ii << dg_dest_names
      ii << ' '
      #ii << item['calls']
      ii <<{ text: nice_time(item['billsec'], options[:min_type]).to_s, align: :center}
      if options[:show_avg_rate] == 1
        ii << { text: nice_invoice_number((item["price"].to_d / (item["billsec"].to_d / 60).to_d)).to_s, :align => :center}
      end
      ii << {text: nice_invoice_number(item['price'], nice_number_hash).to_s, align: :right}
      items << ii
      break if items.size >= page_limit
      dgids << [item['dgid'], item["user_rate"], item['prefix']] if !dgids.include?([item['dgid'], item['user_rate'], item['prefix']])
      total_time += item['billsec']
      total_price += item['price']
      total_calls += item['calls']
    end
    # prints content for reseller of invoice detailed pdf table
    if user.usertype == 'reseller' || user.is_partner?
      r_calls.each do |item|
        ii = []
        dg_dest_names = item['dg_name']
        if !item['dest_name'].blank?
          dg_dest_names += " - " + item['dest_name']
        end
        if !item['to_did'].blank?
          dg_dest_names = _('Calls_To_Dids')
        end
        ii << dg_dest_names
        ii << ' '
       # ii << item['calls']
        ii << {:text => nice_time(item['billsec'], options[:min_type]).to_s, :align => :center}
        if options[:show_avg_rate] == 1
          ii << {:text => nice_invoice_number((item["price"].to_d / (item["billsec"].to_d / 60).to_d)).to_s, :align => :center}
        end
        ii << {:text => nice_invoice_number(item['price'], nice_number_hash).to_s, :align => :right}
        items << ii
        break if items.size >= page_limit
        # cia
        #break if items.size > 50
        dgids << [item["dgid"], item["user_rate"], item["prefix"]] if !dgids.include?([item["dgid"], item["user_rate"], item["prefix"]])
        total_time += item['billsec']
        total_price += item['price']
        total_calls += item['calls']
      end
    end

    # first page max 19 rows
    # others 31 rows

    empty_row = options[:show_avg_rate].zero? ? [' ', '', '',''] : [' ', '', '', '', '']
    if items.size <= 16
      empty_rows_number = 16 - items.size
      empty_rows_number -= self.tax ? self.tax.applied_tax_list(self.converted_price(ex), :precision => nc).size : 1
      empty_rows_number -= 1 if user.minimal_charge_enabled?
      empty_rows_number += 3 if empty_rows_number < 0
      (empty_rows_number-4).times { items << empty_row } if empty_rows_number > 4
    elsif items.size == 18
      4.times { items << empty_row }
    elsif 26 <= ((items.size - 22) % 31)
      empty_rows_number = 31 - ((items.size - 22) % 31)
      empty_rows_number.times { items << empty_row }
    end

    if options[:show_avg_rate] == 1
      items << [{:text => _('Minimal_Charge_for_Calls') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => [:top]}, nice_cell(' '), nice_cell(' '), nice_cell(self.nice_invoice_number(user.converted_minimal_charge(ex).to_d))] if user.minimal_charge_enabled?
      items << [{:text => _('SUBTOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => (user.minimal_charge_enabled? ? [] : [:top])}, nice_cell(' '), nice_cell(' '), nice_cell(self.nice_invoice_number(self.converted_price(ex)))]
    else
      items << [{:text => _('Minimal_Charge_for_Calls') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => [:top]}, nice_cell(' '), nice_cell(self.nice_invoice_number(user.converted_minimal_charge(ex).to_d))] if user.minimal_charge_enabled?
      items << [{:text => _('SUBTOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => (user.minimal_charge_enabled? ? [] : [:top])}, nice_cell(' '), nice_cell(self.nice_invoice_number(self.converted_price(ex)))]
    end
    items_t, up_string, tax_amount, price_with_tax = tax_items(ex, nc, nice_number_hash, 2, dc, options[:show_avg_rate])
    items += items_t

    if options[:show_avg_rate] == 1
      items << [{:text => _('TOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :border_width => 0}, nice_cell(nice_time(total_time, options[:min_type])), nice_cell(' '), {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    else
      items << [{:text => _('TOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :border_width => 0}, nice_cell(nice_time(total_time, options[:min_type])), {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    end
    # Balance Line functionality from 12.126
    if Confline.get_value("#{prepaid}Invoice_Show_Balance_Line", user.owner_id).to_i == 1 and (Confline.get_value("Show_balance_line_setting").to_i == 1 or Confline.get_value("Show_balance_line_setting").blank?)
      balance = owned_balance_from_previous_month
      to_pay = price_with_tax
      to_pay += balance[1].to_f if balance
      items << [{text: _('total_amount_due') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :border_width => 0}, nice_cell(''), {:text => self.nice_invoice_number(to_pay, nice_number_hash).to_s, :colspan => 2, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    end

    if options[:show_avg_rate] == 0
      pdf.table(items,
                :row_colors => ["FFFFFF", "DDDDDD"], :width => 550,
                :font_size => 10,
                :headers => [_('Service'), ' ', _('Time'), _('Total') + " (#{dc})"],
                :align_headers => {0 => :left, 1 => :right, 2 => :center, 3 => :right},
                :column_widths => {0 => 350}) do
        column(0).style(:align => :left, :height => 15)
        column(1).style(:align => :center, :height => 15)
        column(2).style(:align => :right, :height => 15)
        column(3).style(:align => :center, :height => 15)
        column(4).style(:align => :right, :height => 15)
      end
    else
      pdf.table(items,
                :row_colors => ["FFFFFF", "DDDDDD"], :width => 550,
                :font_size => 10,
                :headers => [_('Service'), ' ', _('Time'), _('Avg_rate'), _('Total') + " (#{dc})"],
                :align_headers => {0 => :left, 1 => :center, 2 => :center, 3 => :right, 4 => :right},
                :column_widths => {0 => 350}) do
        column(0).style(:align => :left, :height => 15)
        column(1).style(:align => :center, :height => 15)
        column(2).style(:align => :right, :height => 15)
        column(3).style(:align => :center, :height => 15)
      end
    end

    pdf.bounding_box([0, pdf.cursor + up_string],
                     :width => 450) do
      pdf = PdfGen::Generate.invoice_footer_pdf(pdf, self, {:show_end_title => true})
    end

    pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 12], :width => pdf.bounds.width do
      pdf.text Confline.get_value("#{prepaid}Invoice_End_Title", user.owner), :size => 12, :align => :center
    end

    has_calls = 0
    invoicedetails.each do |invd|
      has_calls = 1 if invd.invdet_type == 0
    end
    # there are two different pdf tables in this pdf so we
    # need to check if max pages is already reached in first table, if so we shouldnt display calls to dids
    if Confline.get_value("#{options[:prepaid]}Invoice_Show_Calls_In_Detailed", user.owner_id).to_i == 1 && has_calls == 1 && (page_limit - items.size >= 31)
      found_calls = 0
      items2 = []
      pages_used = (items.size.to_f / 31).ceil
      pages_left = limit - pages_used
      page_limit_left = pages_left * 68
      dgids.each do |dca|
        calls2, rcalls = self.direction_calls_by_direction(current_user, dca[0], dca[1], dca[2], options)
        tcalls = 0
        tprice = 0

        if calls2.size > 0
          if options[:tariff_purpose] == "user"
            items2 << [{:text => calls2[0]["dg_name"].blank? ? _('Calls_To_Dids') : calls2[0]["dg_name"].to_s}, '', '', '']
          else
            items2 << [{:text => calls2[0]["dg_name"].blank? ? _('Calls_To_Dids') : calls2[0]["dg_name"].to_s + " " + calls2[0]["prefix"].to_s}, '', '', '']
          end
          items2 << [_('Calldate'), _('Billsec'), _('Destination'), _('Price') + " (#{dc})"]
          calls2.each do |item|
            items2 << [
                item['calldate'],
                item["#{options[:billsec_cond]}"],
                (hide_dst ? item['dst'].to_s.strip[0..-4] + 'XXX' : item['dst'].to_s.strip),
                nice_invoice_number(item["user_price"].to_d, nice_number_hash).to_s
            ]
            tprice += item["user_price"].to_d
            break if items2.size > page_limit_left
          end
          tcalls += calls2.size.to_i
        end
        break if items2.size > page_limit_left
        if (user.usertype == "reseller" || user.is_partner? and rcalls.size > 0)
          items2 << [{:text => rcalls[0]["dg_name"].to_s.blank? ? _('Calls_To_Dids') : rcalls[0]["dg_name"].to_s}, '', '', ''] if options[:tariff_purpose] == "user"
          items2 << [{:text => rcalls[0]["dg_name"].to_s.blank? ? _('Calls_To_Dids') : rcalls[0]["dg_name"].to_s + " " + rcalls[0]["prefix"].to_s}, '', '', ''] if options[:tariff_purpose] != "user"
          items2 << [_('Calldate'), _('Billsec'), _('Destination'), _('Price') + " (#{dc})"]
          rcalls.each do |item|
            items2 << [
                item['calldate'],
                item["#{options[:billsec_cond]}"],
                (hide_dst ? item['dst'].to_s.strip[0..-4] + 'XXX' : item['dst'].to_s.strip),
                nice_invoice_number(item["reseller_price"].to_d, nice_number_hash).to_s
            ]
            tprice += item["reseller_price"].to_d
            break if items2.size > page_limit_left
          end
          tcalls += rcalls.size.to_i
        end
        found_calls += tcalls.to_i
        items2 << [_('Total_calls_invoice') + ": " + tcalls.to_s + ", " + _('price_invoice') + ": " + nice_invoice_number(tprice).to_s + " (" + nice_invoice_number(user.get_tax.count_tax_amount(tprice)).to_s + ")"]
        items2 << [' ', '', '', '']
        break if items2.size > page_limit_left
      end
      page_limit_error = 1 if items2.size > page_limit_left
      items2 =  items2[0..page_limit]

      items2[0] = (items2[0] + ['', '','',''])[0..3] unless items2[0].nil?
      if found_calls.to_i > 0
        pdf.table(items2,
                  width: 550,
                  font_size:  7, border_width: 0, vertical_padding: 1,
                  align: {0 => :left, 1 => :right, 2 => :left, 3 => :right}) if dgids.size > 0
      end

    end
    page_limit_error = 1 if (page_limit -items.size <= 31)

    if page_limit_error == 1
      pdf = PdfGen::Count.error_message_from_limit(pdf, limit, current_user, self)
    end

    pdf = pdf_end(pdf, options)
    test_return = []
    test_return = testing_mode ? items : []
    test_return += (testing_mode and items2) ? items2 : []
    return pdf, test_return
  end

  def genereate_options(current_user, ex)
    owner = self.user.owner
    prepaid = (invoice_type.to_s == 'prepaid' and self.user.owner == 0) ? 'Prepaid_' : ''
    user = self.user
    up, rp, pp = user.get_price_calculation_sqls
    opt = {
        user: user,
        tariff_purpose: (user.tariff.nil? ? "user" : user.tariff.purpose),
        format: Confline.get_value('Date_format', current_user.owner_id).gsub('M', 'i'),
        user_price: SqlExport.replace_price(up, {:ex => ex}),
        reseller_price: SqlExport.replace_price(rp, {:ex => ex}),
        partner_price: SqlExport.replace_price('calls.partner_price', {:ex => ex}),
        did_price: SqlExport.replace_price('calls.did_price', {:ex => ex, :reference => 'did_price'}),
        did_sql_price: SqlExport.replace_price('calls.did_price', {:ex => ex, :reference => 'did_price'}),
        did_inc_sql_price: SqlExport.replace_price('calls.did_inc_price', {:ex => ex, :reference => 'did_inc_price'}),
        selfcost: SqlExport.replace_price(pp, {:ex => ex, :reference => 'selfcost'}),
        user_rate: SqlExport.replace_price('calls.user_rate', {:ex => ex, :reference => 'user_rate'}),
        zero_calls_sql: user.invoice_zero_calls.to_i == 0 ? " AND calls.user_price > 0 " : "",
        owner: owner,
        prepaid: prepaid,
        limit: Confline.get_value("#{prepaid}Invoice_page_limit", owner).to_i,
        min_type: (Confline.get_value("#{prepaid}Invoice_Show_Time_in_Minutes", owner).to_i == 1) ? 1 : 0,
        show_avg_rate: (Confline.get_value("#{prepaid}Invoice_Add_Average_rate", owner).to_i == 1) ? 1 : 0,
        billsec_cond: Confline.get_value("Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec',
        company: Confline.get_value("Company", user.owner_id)
    }
  end

  def direction_calls(options={})
    user_timezone = options[:user].time_zone
    calls_calldate_from = (Time.parse("#{period_start} 00:00:00") - Time.parse("#{period_start} 00:00:00").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{period_start} 00:00:00").utc_offset().second)
    calls_calldate_till = (Time.parse("#{period_end} 23:59:59") - Time.parse("#{period_end} 23:59:59").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{period_end} 23:59:59").utc_offset().second)
    calls_calldate_from = "#{calls_calldate_from.strftime('%Y-%m-%d %H:%M:%S')}"
    calls_calldate_till = "#{calls_calldate_till.strftime('%Y-%m-%d %H:%M:%S')}"

    if options[:tariff_purpose] == "user"

      # "devices.user_id" is used because it is possible that calls.user_id will be changed in calling process, but calls.src_device_id is permanent.

      sql = "SELECT
              calls.user_rate as 'user_rate', destinationgroups.id as 'dgid', destinationgroups.flag as 'dg_flag',
              destinationgroups.name as 'dg_name', destinations.name as 'dest_name',
              COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec',
              #{options[:selfcost]}, SUM(#{options[:user_price]}) as 'price', #{options[:did_price]}, calls.prefix,
              dids.did as 'to_did'
            FROM calls " +
              "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst " +
              "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) " +
              "LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) " +
              "JOIN devices ON (calls.src_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} " +
            "WHERE calls.calldate BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'  AND calls.disposition = 'ANSWERED' " +
              "AND card_id = 0 AND (devices.user_id = '#{options[:user].id}'  ) #{options[:zero_calls_sql]}" +
            "GROUP BY destinations.prefix, to_did , calls.user_rate " +
            "ORDER BY destinationgroups.name ASC"

      if options[:user].usertype == "reseller" || options[:user].is_partner?
        user_price_sql = options[(options[:user].usertype + '_price').to_sym]
        owner_id_sql = options[:user].usertype == "reseller" ? 'calls.reseller_id' : 'calls.partner_id'

        sql2 = "SELECT
                  calls.user_rate as 'user_rate', destinationgroups.id as 'dgid', destinationgroups.flag as 'dg_flag',
                  destinationgroups.name as 'dg_name', destinations.name as 'dest_name',
                  COUNT(*) as 'calls',
                  SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]},
                  SUM(#{user_price_sql}) as 'price', #{options[:did_price]}, calls.prefix, dids.did as 'to_did' " +
               "FROM calls " +
                 "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst "+
                 "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) " +
                 "LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} "+
               "WHERE calls.calldate BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'  AND calls.disposition = 'ANSWERED' " +
                 "AND card_id = 0 AND (#{owner_id_sql} = '#{options[:user].id}' ) #{options[:zero_calls_sql]}" +
               "GROUP BY destinations.prefix, to_did, calls.user_rate "+
               "ORDER BY destinationgroups.name ASC"
      end
    else
      #wholesale

      sql = "SELECT calls.user_rate as 'user_rate', destinations.id as 'dgid',  directions.name as 'dg_name', destinations.name as 'dest_name', destinations.prefix,  COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]}, SUM(#{options[:user_price]}) as 'price', #{options[:did_price]}, calls.prefix, dids.did as 'to_did' " +
            "FROM calls " +
              "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst " +
              "JOIN devices ON (calls.src_device_id = devices.id) " +
              "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) " +
              "LEFT JOIN directions  ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql} " +
            "WHERE calls.calldate BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'  AND calls.disposition = 'ANSWERED' " +
              "AND card_id = 0 AND (devices.user_id =  '#{options[:user].id}' ) #{options[:zero_calls_sql]} " +
            "GROUP BY destinations.prefix, to_did, calls.user_rate " +
            "ORDER BY directions.name ASC, destinations.name ASC"

      if options[:user].usertype == "reseller" || options[:user].usertype == "partner"
        user_price_sql = options[(options[:user].usertype + '_price').to_sym]
        owner_id_sql = options[:user].usertype == "reseller" ? 'calls.reseller_id' : 'calls.partner_id'

        sql2 = "SELECT calls.user_rate as 'user_rate', destinations.id as 'dgid',  directions.name as 'dg_name', destinations.name as 'dest_name', destinations.prefix,  COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]}, SUM(#{user_price_sql}) as 'price', #{options[:did_price]}, calls.prefix, dids.did as 'to_did' " +
               "FROM calls " +
                 "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst " +
                 "JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) " +
                 "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) " +
                 "LEFT JOIN directions  ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql} " +
               "WHERE calls.calldate BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'  AND calls.disposition = 'ANSWERED' " +
                 "AND card_id = 0 AND (#{owner_id_sql} =  '#{options[:user].id}' )  #{options[:zero_calls_sql]} " +
               "GROUP BY destinations.prefix, to_did, calls.user_rate " +
               "ORDER BY directions.name ASC, destinations.name ASC"
      end
    end
    res = ActiveRecord::Base.connection.select_all(sql)

    if options[:user].usertype == "reseller" || options[:user].is_partner?
      res2 = ActiveRecord::Base.connection.select_all(sql2)
    end

    return res, res2
  end

  def tax_items(ex, nc, nice_number_hash, type, dc, show_avg_rate = 0, font = 10)
    items = []
    tax = self.tax

    tax = self.user.get_tax unless tax
    tax_amount = 0
    up_string = 60
    colspain = type == 1 ? 1 : 2
    if self.tax
      taxes = tax.applied_tax_list(self.converted_price(ex), :precision => nc)
      taxes.each_with_index { |tax_hash, index|
        if tax.get_tax_count > 0
          up_string += 10
          aa = []
          aa << nice_cell(' ', font) if type == 3
          aa << nice_cell(' ', font) if type == 3
          aa << {:text => tax_hash[:name].to_s+ ": " + tax_hash[:value].to_s + " %", :background_color => "FFFFFF", :colspan => colspain, :align => :right, :border_width => 0, :font_size => font}
          aa << nice_cell(' ', font) if type == 2

          if show_avg_rate == 1
            aa << nice_cell(' ', font) if type == 2
          end

          aa << {:text => self.nice_invoice_number(tax_hash[:tax].to_d, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all, :font_size => font}
          aa << {:text => dc} if type == 3
          items << aa
        end
        tax_amount += self.nice_invoice_number(tax_hash[:tax].to_d, nice_number_hash.merge({:no_repl => 1})).to_d

      }
      price_with_tax = self.nice_invoice_number(self.converted_price(ex) + tax_amount, nice_number_hash.merge({:no_repl => 1})).to_d
    else
      price_with_tax = self.nice_invoice_number(self.converted_price_with_vat(ex), nice_number_hash.merge({:no_repl => 1})).to_d
      tax_amount = price_with_tax - self.converted_price(ex)
    end
    return items, up_string, tax_amount, price_with_tax
  end

  def direction_calls_by_direction(current_user, dgid, user_rate_s, prefix, options = {})
    user_price_sql = options[(options[:user].usertype + '_price').to_sym]
    owner_id_sql = options[:user].usertype == "reseller" ? 'calls.reseller_id' : 'calls.partner_id'

    dst = options[:email_or_not] ? SqlExport.hide_dst_for_user_sql(options[:user], "pdf", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"}) : SqlExport.hide_dst_for_user_sql(current_user, "pdf", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"})

    calldate = SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => options[:format], :tz => Time.zone.now.utc_offset()}), "calldate")

    if options[:tariff_purpose] == "user"

      sql = "SELECT destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', #{calldate}, calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{options[:reseller_price]} as reseller_price, #{dst}  FROM calls JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix) LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id AND destinationgroups.id #{dgid.blank? ? "IS NULL" : "= " + dgid.to_s}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (devices.user_id = #{ options[:user].id} AND calls.user_rate = #{user_rate_s} AND calls.prefix = '#{prefix}') ORDER BY calls.calldate ASC"

      if options[:user].usertype == "reseller" || options[:user].is_partner?
        sql2 = "SELECT destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', #{calldate}, calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{user_price_sql} as reseller_price, #{dst}  FROM calls LEFT JOIN destinations ON (destinations.prefix = calls.prefix) LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id AND destinationgroups.id #{dgid.blank? ? "IS NULL" : "= " + dgid.to_s}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (#{owner_id_sql} = #{options[:user].id} AND calls.user_rate = #{user_rate_s} AND calls.prefix = '#{prefix}') ORDER BY calls.calldate ASC"
      end

    else
      sql = "SELECT destinations.id, directions.name as 'dg_name', destinations.prefix, #{calldate}, calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{options[:reseller_price]} as reseller_price, #{dst}  FROM calls 	JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  LEFT	JOIN directions  ON (destinations.direction_code = directions.code AND destinations.id #{dgid.blank? ? "IS NULL" : "= " + dgid.to_s}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (devices.user_id = #{ options[:user].id} AND calls.user_rate = #{user_rate_s} AND calls.prefix = '#{prefix}') ORDER BY calls.calldate ASC"
      if options[:user].usertype == "reseller" || options[:user].is_partner?
        sql2 = "SELECT destinations.id, directions.name as 'dg_name', destinations.prefix, #{calldate},  calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{user_price_sql} as reseller_price, #{dst}  FROM calls   LEFT JOIN destinations ON (destinations.prefix = calls.prefix)   LEFT JOIN directions  ON (destinations.direction_code = directions.code AND destinations.id #{dgid.blank? ? "IS NULL" : "= " + dgid.to_s}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (#{owner_id_sql} = #{options[:user].id} AND calls.user_rate = #{user_rate_s} AND calls.prefix = '#{prefix}') ORDER BY calls.calldate ASC"
      end
    end

    res = ActiveRecord::Base.connection.select_all(sql)

    if options[:user].usertype == "reseller" || options[:user].is_partner?
      res2 = ActiveRecord::Base.connection.select_all(sql2)
    end

    return res, res2
  end

  def generate_invoice_by_cid_pdf(current_user, dc, ex, nc, cde, gde, testing_mode = false)

    type = (self.user.postpaid.to_i == 1 || self.user.owner_id != 0) ? '' : "Prepaid_"
    user_id = current_user.is_reseller? ? current_user.id : user.owner
    # if page limit isnt set, default is 20
    limit = Confline.get_value("#{type}Invoice_page_limit", user_id).to_i ? Confline.get_value("#{type}Invoice_page_limit", user_id).to_i : 20
    max_limit = Confline.get_value('Max_PDF_pages').to_i
    limit = max_limit if limit > max_limit && max_limit > 0
    page_limit = 38 + 69 * (limit - 1)
    nice_number_hash = { change_decimal: cde, global_decimal: gde, nc: nc}

    options = self.genereate_options(current_user, ex)
    user = options[:user]
    opt_did_sql_price = options[:did_sql_price]
    opt_did_inc_sql_price = options[:did_inc_sql_price]
    opt_zero_calls = options[:zero_calls_sql]
    hide_dst = hide_pdf_dst?(user)


    user_timezone = user.time_zone
    calls_calldate_from = (Time.parse("#{period_start} 00:00:00") - Time.parse("#{period_start} 00:00:00").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{period_start} 00:00:00").utc_offset().second)
    calls_calldate_till = (Time.parse("#{period_end} 23:59:59") - Time.parse("#{period_end} 23:59:59").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{period_end} 23:59:59").utc_offset().second)
    calls_calldate_from = "#{calls_calldate_from.strftime('%Y-%m-%d %H:%M:%S')}"
    calls_calldate_till = "#{calls_calldate_till.strftime('%Y-%m-%d %H:%M:%S')}"
    sql = "SELECT calls.src,
                  #{opt_did_sql_price},
                  #{opt_did_inc_sql_price},
                  CONCAT(devices.device_type, '/', devices.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(devices.callerid, '<', -1), '>', 1), ')') AS nice_src_device
           FROM calls
           JOIN devices ON (calls.src_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}
           WHERE devices.user_id = #{user.id}
                 AND calls.calldate
                 BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'
                 AND calls.disposition = 'ANSWERED'
                 AND billsec > 0
                 AND card_id = 0 #{opt_zero_calls}
           GROUP BY calls.src;"

    cids = ActiveRecord::Base.connection.select_all(sql)
    items = []
    dst = options[:email_or_not] ? SqlExport.hide_dst_for_user_sql(options[:user], 'pdf', SqlExport.column_escape_null('calls.localized_dst'), { as: 'dst' }) : SqlExport.hide_dst_for_user_sql(current_user, 'pdf', SqlExport.column_escape_null('calls.localized_dst'), { as: 'dst' })
    calldate = SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {format: options[:format], tz: current_user.time_offset}), 'calldate')
    ttp = 0
    cids.each do |cid|
      src = cid["src"]
      sql = "SELECT #{dst}, #{calldate}, #{options[:billsec_cond]} as billsec,
                    #{opt_did_inc_sql_price}, #{opt_did_sql_price},
                    #{options[:user_rate]}, #{options[:user_price]} as 'user_price',
                    directions.name as 'direction'
             FROM calls #{SqlExport.left_join_reseler_providers_to_calls_sql}
             LEFT JOIN devices ON (calls.src_device_id = devices.id)
             LEFT JOIN destinations ON (calls.prefix = destinations.prefix)
             LEFT JOIN directions ON (destinations.direction_code = directions.code)
             WHERE devices.user_id = #{user.id}
                   AND calls.calldate
                   BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'
                   AND calls.disposition = 'ANSWERED'
                   AND billsec > 0
                   AND card_id = 0
                   AND calls.src = '#{src}' #{opt_zero_calls}
             ORDER BY calls.calldate ASC"
      calls = ActiveRecord::Base.connection.select_all(sql)

      items << ["#{_('Client_number')}/#{_('Device_details')}: ", "#{src} / #{cid['nice_src_device']}", '', '', '', '']

      calls_to_dids = Hash.new(0)
      calls_to_dids[:count] = calls.select {|call| call['direction'].blank? ? (calls_to_dids[:time] += call['billsec'];calls_to_dids[:price] += call['user_price'];true) : false }.size
      if calls_to_dids[:count] > 0
        items << [' ', '', '', '', '', '']
        items << [' ', _('Duration'),_('Price'),'','']
        items << [_('Calls_To_Dids') + ": ", nice_time(calls_to_dids[:time], options[:min_type]), nice_invoice_number(calls_to_dids[:price], nice_number_hash)," #{dc}" + " (" + _('Without_VAT') + ")", '']
      end
      items << [' ', '', '', '', '', '']

      items << [_('Number'), _('Date'), _('Duration'), _('Rate'), _('Price') + " (#{dc})", _('Destination')]

      calls.each do |item|
        unless item['direction'].blank?
          items << [
                    (hide_dst ? item['dst'].to_s.strip[0..-4]+ 'XXX' : item['dst'].to_s.strip),
                    item["calldate"],
                    nice_time(item["billsec"], options[:min_type]),
                    nice_invoice_number(item["user_rate"], nice_number_hash),
                    nice_invoice_number(item["user_price"], nice_number_hash),
                    item["direction"].to_s
                    ]
          break if items.size > page_limit
        end
      end

      sql = "SELECT directions.name as 'direction',
                    SUM(#{options[:user_price]}) as 'price',
                    COUNT(calls.src) as 'calls',
                    dids.did as to_did
             FROM calls
             LEFT JOIN dids on dids.id = calls.did_id AND calls.dst = dids.did
             LEFT JOIN devices ON (calls.src_device_id = devices.id)
             LEFT JOIN destinations ON (calls.prefix = destinations.prefix)
             LEFT JOIN directions ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql}
             WHERE devices.user_id = #{user.id}
                   AND calls.calldate
                   BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'
                   AND calls.disposition = 'ANSWERED'
                   AND card_id = 0
                   AND calls.src = '#{src}'
            GROUP BY directions.name
            ORDER BY directions.name ASC"

      directions = ActiveRecord::Base.connection.select_all(sql)

      total_price = 0.0
      items << [' ', '', '', '', '', '']
      directions.each do |item|
        items << [
            '',
            '',
            '',
            item['direction'],
            nice_invoice_number(item['price'], nice_number_hash),
            dc.to_s + ' (' + _('Without_VAT') + ')'
        ] unless item['direction'].blank?
        total_price += item["price"].to_d
      end

      items << ['', '', '', _('Total') + ':', nice_invoice_number(total_price, nice_number_hash), dc.to_s + " (" + _('Without_VAT') + ")"]
      items << [' ', '', '', '', '', '']
      ttp += total_price.to_d
      break if items.size > page_limit
    end

    sql = "SELECT COUNT(calls.id) as calls_size,
                  SUM(#{options[:billsec_cond]}) as billsec,
                  SUM(#{options[:user_price]}) as 'user_price'
           FROM calls JOIN devices ON (calls.dst_device_id = devices.id)
           #{SqlExport.left_join_reseler_providers_to_calls_sql}
           WHERE devices.user_id = #{user.id}
                 AND calls.calldate
                 BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}'
                 AND calls.disposition = 'ANSWERED'
                 AND billsec > 0
                 AND card_id = 0
                 #{opt_zero_calls};"

    in_calls = ActiveRecord::Base.connection.select_all(sql)

    if in_calls and in_calls[0]['calls_size'].to_i > 0
      items << [_('incoming_calls'), _('Duration'), _('Price') + " (#{dc})", '', '', '']
      items << ['', nice_time(in_calls[0]["billsec"], options[:min_type]), nice_invoice_number(in_calls[0]["user_price"], nice_number_hash), '', '', '']
      ttp += in_calls[0]["user_price"].to_d
      items << [' ', '', '', '', '', '']
    end

    end_file = -4
    if (items.size + 10) > page_limit
      items << [' ', '', '', '', '', '']
      items << [{ text: 'Invoice reached maximum number of #{limit} pages to show.', colspan: 6 }]
      items << [{ text: 'Please read CSV file to see all the data.', colspan: 6 }]
      end_file -= 2
    end

    if invoicedetails && invoicedetails.size.to_i > 0
      invoicedetails.where("invdet_type = 0").each do |id|
        items << ['', { text: id.nice_inv_name, colspan: 3 }, self.nice_invoice_number((id.converted_price(ex)), nice_number_hash).to_s, dc.to_s + " (" + _('Without_VAT') + ")"]
        ttp += id.price.to_d
      end
      invoicedetails.where("invdet_type > 0").order(:name).each do |id|
        items << ['', { text: id.nice_inv_name, colspan: 3 }, self.nice_invoice_number((id.quantity * id.converted_price(ex)), nice_number_hash).to_s, dc.to_s + " (" + _('Without_VAT') + ")"]
        ttp += id.price.to_d
      end
      end_file -= 2
      items << [' ', '', '', '', '', '']
    end

    if user.minimal_charge_enabled?
      items << [' ', { text: _('Minimal_Charge_for_Calls'), colspan: 3 }, nice_cell(self.nice_invoice_number(user.converted_minimal_charge(ex).to_d)), dc.to_s]
      items << [' ', '', '', '', '', '']
      end_file -= 2
    end

    items << ['', { text: _('TOTAL') + ':', colspan: 3, align: :right }, nice_cell(self.nice_invoice_number(self.converted_price(ex))), dc.to_s + " (" + _('Without_VAT') + ")"]
    items_t, up_string, tax_amount, price_with_tax = tax_items(ex, nc, nice_number_hash, 3, dc, options[:show_avg_rate], 7)
    items += items_t
    items << ['', { text: _('TOTAL') + ':', colspan: 3, align: :right }, {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :align => :right}, dc]

    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf = PdfGen::Generate.invoice_header_pdf(self, pdf, options[:company], current_user.currency.name)

    items << [' ', '', '', '', '', ''] if items.size.to_i < 1

    items =  items[0..page_limit] + items[end_file..-1] if items.size > page_limit
    pdf.table(items,
              width: 550,
              font_size: 7, border_width: 0, vertical_padding: 1,
              align: {0 => :left, 1 => :right, 2 => :left, 3 => :right},
              column_widths: {0 => 100, 1=> 100, 2 => 50, 3 => 100, 4 => 50, 5 => 100})

    pdf = pdf_end(pdf, options)

    if items.size > page_limit
      pdf = PdfGen::Count.error_message_from_limit(pdf, limit, current_user, self)
    end

    test_return = testing_mode ? items : []
    return pdf, test_return
  end

  def new_invoice_type(user)
    if invoice_type.to_s == 'prepaid' and user.owner_id == 0
      return 'Prepaid_', 'prepaid'
    else
      return '', 'postpaid'
    end
  end

  def pdf_end(pdf, options)
    add_details = Confline.get_value("#{options[:prepaid]}Invoice_show_additional_details_on_separate_page", options[:owner].id)
    add_details2 = Confline.get_value2("#{options[:prepaid]}Invoice_show_additional_details_on_separate_page", options[:owner].id)
    if add_details.to_i == 1 and !add_details2.to_s.strip.blank?
      pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{options[:prepaid]}Invoice_show_additional_details_on_separate_page", options[:owner].id))
    end
    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt
    return pdf
  end

  def nice_cell(text, font = nil)
    {:text => text.to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all, :font_size => font}
  end

  def nice_invoice_number(number, options = {})
    nc = options[:apply_rounding] ? (options[:nc] ? options[:nc] : self.invoice_precision) : self.invoice_precision
    num = sprintf("%0.#{nc}f", number.to_d) if number
    num = num.gsub('.', options[:global_decimal]) if options[:change_decimal] && (options[:no_repl].to_i == 0)
    num
  end

  def nice_time(time, type)
    if type.to_i == 0
      nice_time_inv(time)
    else
      nice_time_in_minits(time)
    end
  end

  def nice_time_in_minits(time)
    time = time.to_i
    return '' if time == 0
    m = time / 60
    s = time - (60 * m)
    good_date(m) + ':' + good_date(s)
  end

  def nice_time_inv(time)
    time = time.to_i
    return '' if time == 0
    h = time / 3600
    m = (time - (3600 * h)) / 60
    s = time - (3600 * h) - (60 * m)
    good_date(h) + ':' + good_date(m) + ':' + good_date(s)
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = "0" + dd if dd.length<2
    dd
  end

  def owned_balance_from_previous_month
    user = self.user
    # check if invoice is for whole month
    first_day = self.period_start.to_s[8, 2]
    last_day = self.period_end.to_s[8, 2]
    year = self.period_start.to_s[0, 4]
    month = self.period_start.to_s[5, 2].to_i.to_s #remove leading 0

    if first_day.to_i == 1 and last_day.to_i == Invoice.last_day_of_month(year, month).to_i
      # get balance from actions for last month
      action = Action.where("user_id = #{self.user_id} AND action = 'user_balance_at_month_end' AND data = '#{year}-#{month}'").first
      if action
        # count invoice details price in invoice
        #inv_details_price = 0.0
        #inv_details = invoice.invoicedetails
        #inv_details.each{|id| inv_details_price += id.price.to_d if id.invdet_type > 0}

        # count calls price in invoice
        inv_calls_price = 0.0
        inv_details = self.invoicedetails
        inv_details.each { |id| inv_calls_price += id.price.to_d if id.invdet_type == 0 }

        # count balance
        #balance = sprintf("%0.#{2}f", user.balance.to_d + user.get_tax.count_tax_amount(user.balance.to_d ))
        #owned_balance = action.data2.to_d - inv_details_price.to_d
        owned_balance = (action.data2.to_d * (-1)) - inv_calls_price.to_d

        balance_with_tax = owned_balance.to_d + user.get_tax.count_tax_amount(owned_balance.to_d)
        return [owned_balance, balance_with_tax]
      else
        MorLog.my_debug("Balance will not be shown because not found balance at the end of month, invoice id: #{id}")
        return nil
      end
    else
      MorLog.my_debug("Balance will not be shown because invoice is not for whole month, invoice id: #{id}")
      return nil
    end
  end


  def generate_taxes_for_invoice(nc, ex = 0)
    self.tax = self.user.get_tax unless tax
    taxes = self.tax.applied_tax_list(self.price, { precision: nc })
    self.tax_1_value = self.nice_invoice_number(taxes[0][:tax] , { nc: nc, apply_rounding: true })
    self.tax_2_value = self.nice_invoice_number(taxes[1][:tax] , { nc: nc, apply_rounding: true }) if taxes[1]
    self.tax_3_value = self.nice_invoice_number(taxes[2][:tax] , { nc: nc, apply_rounding: true }) if taxes[2]
    self.tax_4_value = self.nice_invoice_number(taxes[3][:tax] , { nc: nc, apply_rounding: true }) if taxes[3]
    if ex != 0
      self.price_with_vat = self.nice_invoice_number(self.price_with_tax({ precision: nc, ex: ex }) , { nc: nc, apply_rounding: true })
    else
      self.price_with_vat = self.nice_invoice_number(self.price_with_tax({ precision: nc }) , { nc: nc, apply_rounding: true })
    end
    self
  end

  def Invoice.last_day_of_month(year, month)
    Date.new(year.to_i, month.to_i).end_of_month.day
  end

  def pay(params, owner_id)
    if self.paid == 0
      self.paid = 1
      format = "%Y-%m-#{params[:date].try(:[], :day) || '%d'}"
      self.paid_date = Time.now.strftime(format)

      if params[:create_payment].to_i == 1
        self.payment = Payment.pay_for_invoice(self.payment, self, owner_id)
        self.user.balance += self.price
      end
    else
      self.paid = 0

      if self.payment
        self.payment.destroy
        self.user.balance -= self.price
      end
    end
    self.user.save
    self.save
  end

  def toggle_status(status)
    case(status.to_s)
    when 'email'
      self.sent_email = (self.sent_email == 0 ? 1 : 0)
    when 'manually'
      self.sent_manually = (self.sent_manually == 0 ? 1 : 0)
    end
    self.save
  end

  def exchange_rate(default_currency, dc, current_user)
    if self.invoice_currency.to_s == dc || (self.user_id == current_user.id && self.invoice_currency.present?)
      self.invoice_exchange_rate
    else
      Currency.count_exchange_rate(default_currency, dc)
    end
  end

  def self.for_send(owner_id, sent_options)
    cond = []

    # params that need to be searched with appended any value via LIKE in users table
    ['username', 'first_name', 'last_name'].each { |col|
      cond << "users.#{col} LIKE '#{sent_options["s_#{col}".intern].to_s}'" if sent_options["s_#{col}".to_sym].present?
    }

    # params that need to be searched with appended any value via LIKE in invoices table
    cond << "invoices.number LIKE '#{sent_options[:s_number].to_s}'" if sent_options[:s_number].present?

    # params that need to be searched via equality.
    ['period_start', 'period_end', 'issue_date', 'sent_email', 'sent_manually', 'paid', 'invoice_type'].each { |col|
      cond << "invoices.#{col} = '#{sent_options["s_#{col}".to_sym]}'" if sent_options["s_#{col}".to_sym].present?
    }

    cond << "users.owner_id = #{owner_id}"
    cond << 'users.send_invoice_types > 0'

    Invoice.includes([:user, :tax]).where(cond.join(' AND ')).references(:user)
  end

  def self.get_invoices_for_api(cond, from_nice, till_nice)
    Invoice.select('invoices.*').
      joins('JOIN users ON (users.id = invoices.user_id)').
      where(["period_start >= ? AND period_end <= ? AND users.generate_invoice != 0 #{cond}", from_nice, till_nice])
  end

  def self.invoice_numbers_by_owner_id(owner_id)
    select('number').
        joins('JOIN users ON users.id = invoices.user_id').
        where("users.owner_id = #{owner_id}").
        pluck(:number)
  end

  def self.api_invoice_generate(invoice_by_id)
    invoice_number = invoice_by_id.number
    inv_user_owner = invoice_by_id.user.owner
    inv_user_owner.create_xlsx_conflines_if_not_exists
    inv_user_owner_id = inv_user_owner.id
    templates_name_ending = (inv_user_owner.is_admin?) ? '' : '_' + inv_user_owner_id.to_s
    template_path = "#{Actual_Dir}/public/invoice_templates/default#{templates_name_ending}.xlsx"
    file_path, file_name = ["/tmp/mor/invoices/#{invoice_number}.xlsx", "#{invoice_number}.xlsx"]

    round_2_dec = Confline.get_value('Round_finals_to_2_decimals').to_i
    if round_2_dec != 1
      precision = invoice_by_id.invoice_precision.present? ? invoice_by_id.invoice_precision : Confline.get_value('Nice_Number_Digits')
    else
      precision = 2
    end

    invoice_template = TemplateXL::X6InvoiceTemplate.new(template_path, file_path, inv_user_owner_id, precision)
    invoice_template.invoice, invoice_template.invoicedetails = invoice_by_id.copy_for_xslx
    invoice_template.generate
    invoice_template.save
  end

  def invoicedetails_ordered
    invoice_id = self.id
     sql =
          "SELECT id, invoice_id,
              'Calls' AS name,
              SUM(quantity) AS quantity,
              SUM(price) AS price,
              0 AS invdet_type,
              prefix,
              SUM(total_time) AS total_time
       FROM invoicedetails
       WHERE invoice_id = #{invoice_id}
             AND (prefix IS NOT NULL AND prefix != '')
       UNION
       SELECT invoicedetails.id,
              invoicedetails.invoice_id,
              invoicedetails.name,
              invoicedetails.quantity,
              invoicedetails.price,
              invoicedetails.invdet_type,
              invoicedetails.prefix,
              invoicedetails.total_time
       FROM invoicedetails
       WHERE invoice_id = #{invoice_id}
             AND (prefix IS NULL OR prefix = '') ORDER BY invdet_type, name;"
      return Invoicedetail.find_by_sql(sql)
  end

  def invoicedetails_grouped
    invoice_id = self.id
    sql =
          "
          SELECT id, invoice_id,
              'Calls' AS name,
              SUM(quantity) AS quantity,
              SUM(price) AS price,
              0 AS invdet_type,
              prefix,
              SUM(total_time) AS total_time,
              service_id
          FROM invoicedetails
          WHERE invoice_id = #{invoice_id}
             AND (prefix IS NOT NULL AND prefix != '')
          UNION

          SELECT invoicedetails.id, invoice_id,
              IFNULL(services.name, invoicedetails.name) AS name, invoicedetails.quantity,
              SUM(invoicedetails.price) AS price, invdet_type,
              prefix, total_time, service_id
          FROM invoicedetails
          LEFT JOIN services ON services.id = invoicedetails.service_id
          WHERE invoice_id = #{invoice_id} AND (prefix IS NULL OR prefix = '')
          GROUP BY service_id ORDER BY invdet_type, name"
    return Invoicedetail.find_by_sql(sql)
  end

  def grouped_by_destination_and_service
    invoice_id = self.id
    sql =
          "
          SELECT id, invoice_id,
              name, quantity,
              price, 0 AS invdet_type,
              prefix, total_time,
              service_id, 0 AS 'invoice_detail_type'
          FROM invoicedetails
          WHERE invoice_id = #{invoice_id}
             AND (prefix IS NOT NULL AND prefix != '')

          UNION

          SELECT invoicedetails.id, invoice_id,
              invoicedetails.name AS name, invoicedetails.quantity,
              SUM(invoicedetails.price) AS price, invdet_type,
              prefix, total_time, service_id, 1 AS 'invoice_detail_type'
          FROM invoicedetails
          WHERE invoice_id = #{invoice_id} AND (prefix IS NULL OR prefix = '') AND invdet_type = 0

          UNION

          SELECT invoicedetails.id, invoice_id,
              IFNULL(services.name, invoicedetails.name) AS name, invoicedetails.quantity,
              SUM(invoicedetails.price) AS price, invdet_type,
              prefix, total_time, service_id, 2 AS 'invoice_detail_type'
          FROM invoicedetails
          LEFT JOIN services ON services.id = invoicedetails.service_id
          WHERE invoice_id = #{invoice_id} AND invdet_type = 1
          GROUP BY service_id ORDER BY invoice_detail_type, name"
    return Invoicedetail.find_by_sql(sql)
  end

  def generate_prepaid_csv
    # Export Call data on file (spare RAM)
    file_name = "#{number}_#{Time.now.to_i}"
    file_path = "/tmp/mor/invoices/#{file_name}.csv"

    ActiveRecord::Base.connection.execute("
      SELECT
        calls.calldate, calls.src,
        calls.dst, calls.billsec,
        #{SqlExport.user_price_sql} AS user_price,
        destinations.name
      FROM calls
      JOIN devices ON (
        devices.id = calls.src_device_id
          OR devices.id = calls.dst_device_id
      )
      LEFT JOIN destinations ON (
        destinations.prefix = calls.prefix
      )
      #{SqlExport.left_join_reseler_providers_to_calls_sql}
      WHERE devices.user_id  = #{user.id}
        AND disposition = 'ANSWERED'
        AND calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'
      ORDER BY calls.calldate ASC
      INTO OUTFILE '#{file_path}'
      FIELDS TERMINATED BY ','
      LINES TERMINATED BY '\\n'"
    )

    # If the Database is on a separate Server
    if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
      # Create a file and load content to it from a remote Server
      system "touch #{file_path}"
      load_file_through_database(file_name, 'csv', '/tmp/mor/invoices/', true)
    end

    file_path
  end

  private

  def hide_pdf_dst?(user)
    user.usertype != 'admin' && [4, 5, 6, 7].member?(user.hide_destination_end.to_i)
  end
end
