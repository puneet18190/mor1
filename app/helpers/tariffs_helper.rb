# -*- encoding : utf-8 -*-
module TariffsHelper
  def destination_rate_details(rate, tariff)
    details_count = rate.ratedetails.size
    if (details_count == 1)
      rate_detail_rate = rate.ratedetails.first.try(:rate)
      link_text = rate_detail_rate == -1 ? _('Blocked') : nice_number(rate_detail_rate)
    else
      link_text = _('Details')
    end
    style = check_rate_active(rate)
    link_to b_details + link_text, {:action => 'rate_details', :id => rate.id}, :id => "details_img_"+rate.id.to_s, :style => style
  end

  def check_rate_active(rate)
    (@effective_from_active and rate.active == 0) ? "color: #BFBFBF;" : ""
  end

  def mark_active_rates(rates)
    skip = 0
    active_effective = nil
    # We need to sort the rates to properly perform marking.
    # Note: works on the same prefix and tariff rates.
    rates.sort_by! { |rate| [rate['effective_from'].to_s] }.reverse!
    current_time = current_user.user_time(Time.new)
    # Mark each rates list entry as active/inactive
    rates.each do |rate|
      effective_from = rate['effective_from']
      is_active = 0
      # Process the newest not newer than today effective from date
      if skip == 0 && effective_from.present? && effective_from <= current_time
        is_active = skip = 1
        active_effective = effective_from
      end
      # If there are any rates with the same effective from as the
      # active one make them active too
      is_active = 1 if effective_from.to_i == active_effective.to_i
      rate['active'] = is_active
    end
  end

  def find_longest_prefix_rate(rates)
    max_len = 0
    rates.try(:each) do |rate|
      prefix_length = rate['prefix'].to_s.length
      max_len = prefix_length if prefix_length > max_len
    end
    find_all_same_length(rates, max_len)
  end

  def find_all_same_length(rates, length)
    result = []
    rates.try(:each) do |rate|
      result.push(rate) if rate['prefix'].to_s.length == length
    end
    result
  end

  def find_rates(tariff_id)
    Rate.where(tariff_id: tariff_id, destination_id: !0)
  end

  def finf_custom_rates(dg_id)
    Customrate.where(user_id: session[:user_id], destinationgroup_id: dg_id).first
  end

  def b_make_tariff
    image_tag('icons/application_add.png', :title => _('Make_tariff')) + " "
  end

  def link_nice_tariff_simple(tariff)
    if tariff.purpose == 'user'
      link_to tariff.name, :controller => "tariffs", :action => "user_rates_list", :id => tariff.id, :st => "A"
    elsif tariff.purpose == 'user_wholesale'
      link_to tariff.name, :controller => "tariffs", :action => "rates_list", :id => tariff.id, :st => "A"
    elsif tariff.purpose == 'provider'
      link_to tariff.name, :controller => "tariffs", :action => "rates_list", :id => tariff.id, :st => "A"
    end
  end

  def link_nice_tariff_retail(tariff)
    out = "<b>#{_('Tariff')}: </b>"
    out += link_to tariff.name, :controller => "tariffs", :action => "user_rates_list", :id => tariff.id, :st => "A"
    out += "<br><br>"
  end

  def effective_from_date_formats
    formats = ['%Y-%m-%d', '%Y/%m/%d', '%Y,%m,%d', '%Y.%m.%d', '%d-%m-%Y', '%d/%m/%Y',
               '%d,%m,%Y', '%d.%m.%Y', '%m-%d-%Y', '%m/%d/%Y', '%m,%d,%Y', '%m.%d.%Y']
    formats.map{|format| [format.gsub('%', ''), format]}
  end

  def guess_effective_from_format(datetime = '')
    date = datetime.to_s.split[0].to_s
    date_separator = ''
    date_values = []

    ['-', '/', ',', '.'].each do |possible_seperator|
      date_values = date.split(possible_seperator)
      if date_values.size == 3
        date_separator = possible_seperator
        break
      end
    end

    return nil if date_separator.blank?
    format = []

    if date_values[0].length == 4
      format[0] = '%Y'
      format[1] = '%m'
      format[2] = '%d'
    else
      format[2] = '%Y'

      if date_values[1].to_i > 12
        format[0] = '%m'
        format[1] = '%d'
      else
        format[0] = '%d'
        format[1] = '%m'
      end
    end

    return format.join(date_separator)
  end

  def count_active_rates(tariff_id)
    sql = "SELECT COUNT(*) AS active_count FROM (
            SELECT id
              FROM rates
              WHERE (effective_from < NOW() OR effective_from IS NULL) AND rates.tariff_id = #{tariff_id} GROUP BY destination_id) AS active_rates"

    result = ActiveRecord::Base.connection.select(sql)
    result.first['active_count'].to_i
  end

  def default_delta_radio_button(delta_value, delta_percent)
    delta_value.blank? && delta_percent.blank? ? true : delta_value
  end

  def search_directions(params)
    select_clause = "directions.id, directions.name, directions.code,
      COUNT(destinations.id) != COUNT(rates.id) AS 'new_rates_available'"
    join_clause = "LEFT JOIN destinations ON (destinations.direction_code = directions.code)
      LEFT JOIN rates ON (rates.destination_id = destinations.id AND tariff_id = #{params[:tariff_id]})"

    directions = Direction.
      select(select_clause).
      where(params[:directions_name_query]).
      joins(join_clause).order('name ASC').
      group('directions.id').
      all
  end
end
