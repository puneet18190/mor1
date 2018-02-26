require 'rubyXL'
module TemplateXL
  class Template
    def initialize(template_path, save_path, inv_user_owner_id, number_precision = 0)
      parent_template_path = template_path.split('/')[0..-2].join('/')
      parent_save_path = save_path.split('/')[0..-2].join('/')
      if File.exist?(template_path)
        begin
          system("chmod 777 -R #{parent_save_path}")
          system("chmod 777 -R #{parent_template_path}")
          system("chmod +t #{parent_template_path}")
          @workbook = RubyXL::Parser.parse(template_path)
        rescue
          @workbook = RubyXL::Workbook.new
        end
      else
        @workbook = RubyXL::Workbook.new
      end

      @number_precision = number_precision
      @save_path = save_path
      @details, @lines_details, @user_details = [{}, {}, {}]
      @inv_user_owner_id = inv_user_owner_id
      initialize_coordinates
    end

    # This method uses assign_cell_coordinates to collect
    # The method - coordinate pairs that will be added to the template
    # Then it makes the final iteration to modify the key values so they could be evaluated through eval.
    # Finally, the values that come from evaluated hash keys are added to the correspoding cells in the XLSX file.
    def generate
      if !@details.blank? or !@lines_details.blank?
        worksheet = @workbook.first

        if Confline.get_value('invoice_show_balance_line', @inv_user_owner_id).to_i == 1
          debt, debt_with_tax, total_amount_due = balance_line
        else
          @details.delete_if { |key, value| %w[invoice.debt invoice.debt_tax invoice.total_amount_due].include?(key) }
        end
        client = User.where(id: eval("@invoice.user_id").to_i).first

      @user_details.each do |key, value|
        next if value == [-1, -1]
          x, y = value
          begin
            value = key == 'users.clientid' ? client.clientid : client.agreement_number
            add_cell(x, y, value, worksheet)
          rescue NoMethodError
            #Somebody messed with Cell_x6_inv_line conflines
          end
        end

        @details.each do |key, value|
          next if value == [-1, -1]
          x, y = value
          begin
            value = case key
                    when 'invoice.client_details5'
                      # client_details5 should show destination group name, not id
                      direction_id = eval("@#{key}")
                      Direction.where(id: direction_id).first.try(:name).to_s
                    when 'invoice.price', 'invoice.price_with_vat'
                      decimal_if_string_present(nice_value(eval("@#{key}") * invoice.invoice_exchange_rate.to_f, @number_precision))
                    when 'invoice.exchange_rate'
                      decimal_if_string_present(nice_value(eval("@#{key}"), @number_precision))
                    when 'invoice.debt'
                      decimal_if_string_present(nice_value(debt, @number_precision))
                    when 'invoice.debt_tax'
                      decimal_if_string_present(nice_value(debt_with_tax, @number_precision))
                    when 'invoice.total_amount_due'
                      decimal_if_string_present(nice_value(total_amount_due, @number_precision))
                    when 'invoice.client_name'
                      client.nice_name
                    else
                      nice_value(eval("@#{key}"), @number_precision)
                    end
            add_cell(x, y, value, worksheet)
          rescue NoMethodError
            #Somebody messed with Cell_x6_inv_line conflines
          end
        end

        eval(@lines).each do |invoicedetails|
          @lines_details.each do |key, value|
            next if value == [-1, -1]
            x, y = value
            begin
              if key == 'invoice.invoice_exchange_rate' || key == 'invoicedetails.price'
                value = decimal_if_string_present(nice_value(eval(key) * invoice.invoice_exchange_rate.to_f, @number_precision))
              else
                value = nice_value(eval(key) * invoice.invoice_exchange_rate.to_f)
              end

              add_cell(x, y, value, worksheet)
              x = x.next
              @lines_details[key] = [x, y]
            rescue NoMethodError
              #Somebody messed with Cell_x6_inv_line conflines
            end
          end
        end
      end
    end

    def add_cell(x, y, value, worksheet)
      cell = worksheet.try(:[], x).try(:[], y)
      if cell
        cell.change_contents(value)
      else
        worksheet.add_cell(x, y, value)
      end
    end

    def content
      data = File.open(@save_path).try(:read)
      data
    end

    def save
      @workbook.write(@save_path)
    end

    def test
      worksheet_hash = {}
      worksheet = @workbook.worksheets.first

      worksheet.each do |row|
        row && row.cells.each do |cell|
          if cell.is_a?(RubyXL::Cell)
            coord = RubyXL::Reference.ind2ref(cell.row, cell.column)
            value = cell.value.to_s
            worksheet_hash[coord] = value
          end
        end
      end

      worksheet_hash
    end

    private

    def decimal_if_string_present(value)
      value.to_d if value.present?
    end

    def nice_value(value,digits = 0)
      if value.is_a?(Time)
        value = value.strftime('%Y-%m-%d')
      end

      if (digits == 0) || !value.is_a?(Numeric)
        return value
      else
        n = ''
        n = sprintf("%0.#{digits}f", value) if value
        return n
      end
    end

    def balance_line
      price_with_vat = eval('@invoice.price_with_vat').to_f
      no_result = ['', '', price_with_vat]

      if invoice = Invoice.where(number: eval('@invoice.number')).first
        user = invoice.user
        first_day = invoice.period_start.to_s[8, 2]
        last_day = invoice.period_end.to_s[8, 2]
        year = invoice.period_start.to_s[0, 4]
        month = invoice.period_start.to_s[5, 2].to_i.to_s
        if (first_day.to_i == 1) && (last_day.to_i == Invoice.last_day_of_month(year, month).to_i)
          action = Action.where(user_id: invoice.user_id, action: 'user_balance_at_month_end', data: "#{year}-#{month}").first
          if action
            inv_calls_price = 0.0
            inv_details = invoice.invoicedetails
            inv_details.each { |id| inv_calls_price += id.price.to_d if id.invdet_type == 0 }

            owned_balance = (action.data2.to_d * (-1)) - inv_calls_price.to_d

            owned_balance_with_tax = owned_balance.to_d + user.get_tax.count_tax_amount(owned_balance.to_d)

            total_amount_due = price_with_vat + owned_balance_with_tax.to_f
            MorLog.my_debug(total_amount_due)
            return owned_balance, owned_balance_with_tax, total_amount_due
          else
            MorLog.my_debug("Balance will not be shown because not found balance at the end of month, invoice id: #{invoice.id}")
            return no_result
          end
        else
          MorLog.my_debug("Balance will not be shown because invoice is not for whole month, invoice id: #{invoice.id}")
          return no_result
        end

        return no_result
      else
        return no_result
      end
    end
  end
end
