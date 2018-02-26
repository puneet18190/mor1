# -*- encoding : utf-8 -*-
module CdrHelper

  def nice_cdr_import_error(er, owner_id)
    error = ''
    case er.to_i
      when 1
        error = _('CLI_is_not_number')
      when 2
        error = _('CDR_exist_in_db_match_call_date_dst_src')
      when 3
        error = _('Destination_is_not_numerical_value')
      when 4
        error = _('Invalid_calldate')
      when 5
        error = _('Billsec_is_not_numerical_value')
      when 6
        error = _('Provider_ID_not_found_in_DB')
      when 7
        error = "#{_('cli_belongs_to')} #{link_nice_user_by_id(owner_id)}"
      when 8
        error = _('CLI_was_not_found')
    end
    raw error
  end

  def b_testing
    image_tag('icons/lightning.png', title: _('Testing')) + ' '
  end

  def tooltip_export_template_columns(template)
    output = ''

    headers = cdr_export_template_column_headers
    template.columns_array.each_with_index do |column, index|
      output << "#{_('Column')} ##{index + 1}: #{headers[column]} <br/>"
    end

    raw output
  end

  def options_for_select_export_template_columns
    output = [['', '']]
    cdr_export_template_column_headers.each { |value, name| output << [name, value] }
    output.sort
  end

  def cdr_export_template_column_headers
    CdrExportTemplate.column_headers(session[:usertype].to_sym)
  end
end
