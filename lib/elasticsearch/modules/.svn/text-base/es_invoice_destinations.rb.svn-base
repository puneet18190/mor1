#-*- encoding : utf-8 -*-
# Invoice by Destinations ElasticSearch module
module EsInvoiceDestinations
  extend UniversalHelpers

  @options = {}

  module_function

  def csv(options)
    format_options(options)
    # Retrieve the aggregated calls
    response = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.invoice_destinations(@options))
    return [] unless response
    # Generate a CSV
    make_csv(response)
  end

  private

  module_function

  def format_options(options)
    # Invoice User timezone offset
    user_offset = ActiveSupport::TimeZone[options[:user].time_zone].try(:formatted_offset, false)
    # Convert a User time to a Server time
    options[:from] = Time.parse(options[:from] << " #{user_offset}").strftime('%Y-%m-%dT%H:%M:%S')
    options[:till] = Time.parse(options[:till] << " #{user_offset}").strftime('%Y-%m-%dT%H:%M:%S')
    # Id of the User
    options[:user_id] = options[:user].id
    # Device id's which belong to the Invoice Users
    options[:device_ids] = Device.where(user_id: options[:user_id]).pluck(:id)
    # Hide or show zero price Calls
    options[:show_zero_calls] = options[:user].invoice_zero_calls.to_i == 1
    # Merge other options
    @options = options
  end

  def make_csv(response)
    # CSV visual options
    csv_sep = @options[:csv_sep]
    dec_sep = @options[:dec_sep]
    dec_digits = @options[:dec_digits]
    csv = []

    # Calldata grouped by Destinations
    grouped_by_dst = response['aggregations']['grouped_by_dst']['buckets']

    grouped_by_dst.each do |dst_group|
      # Calldata grouped by User Rates
      grouped_by_user_rate = dst_group['grouped_by_user_rate']['buckets']
      # Skip Calls which are failed
      next if grouped_by_user_rate.empty?
      # Prefix of a Call
      prefix = dst_group['key']

      dst = Destination.find_by(prefix: prefix)
      dir = Direction.find_by(code: dst.try(:direction_code))
      # Direction name
      country = dir.try(:name)

      # Total Calls to a Direction
      calls_count = dst_group['doc_count'].to_i

      grouped_by_user_rate.each do |rate_group|
        # User Rate for Direction
        user_rate = rate_group['key'].to_f * @options[:exrate]

        # Total Answered Calls Calldata and number
        answered_calls = rate_group['answered_calls']
        answered_calls_count = answered_calls['doc_count'].to_i

        # Total Billsec
        billsec = answered_calls['billsec']['value'].to_i

        # Total Price
        price = (answered_calls['user_price']['value'].to_f + answered_calls['did_inc_price']['value'].to_f) * @options[:exrate]
        # ASR %
        asr = calls_count > 0 ? answered_calls_count.to_f / calls_count * 100 : 0
        # ACD s
        acd = answered_calls_count > 0 ? billsec.to_f / answered_calls_count : 0

        # Generate a CSV line
        csv << "#{country} #{prefix.to_s}#{csv_sep}"\
          "#{nice_number_with_separator(user_rate, dec_digits, dec_sep)}#{csv_sep}"\
          "#{nice_number_with_separator(asr, dec_digits, dec_sep)}#{csv_sep}"\
          "#{answered_calls_count}#{csv_sep}"\
          "#{nice_number_with_separator(acd, dec_digits, dec_sep)}#{csv_sep}"\
          "#{billsec}#{csv_sep}"\
          "#{nice_number_with_separator(price, dec_digits, dec_sep)}"
      end
    end
    # Sort CSV and add a header
    csv.sort!
  end
end