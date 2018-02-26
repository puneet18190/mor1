#-*- encoding : utf-8 -*-
module EsInvoiceByCidCsv
  extend UniversalHelpers

  def self.get_data(options)
    all_calls = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.generate_invoice_by_cid_cs(options))

    return nil unless all_calls

    cids = all_calls['aggregations']['group_by_src']['buckets']
    data = []
    user = options[:user]
    usertype = user.usertype
    exchange_rate = user.try(:currency).try(:exchange_rate).to_d
    exchange_rate_value = exchange_rate == 0 ? 1 : exchange_rate

    cids.each do |bucket|
      src = bucket['key'].to_s
      total_reseller_price = 0
      total_user_price = 0
      total_partner_price = 0
      total_reseller_price = bucket['total_reseller_price']['provider_agg']['reseller_price']['value'] if usertype == 'reseller'
      total_did_inc_price = bucket['total_did_inc_price']['value']
      total_partner_price = bucket['total_partner_price']['partner_price']['value'] if usertype == 'partner'
      total_user_price = bucket['total_user_price']['user_price']['value'] if usertype == 'user'
      calls = bucket['doc_count']

      total_price = (total_reseller_price + total_did_inc_price + total_partner_price + total_user_price) * exchange_rate_value

      call = {
          src: src,
          calls: calls,
          total: total_price
      }
      data << call
    end
    return data
  end
end
