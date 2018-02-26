#-*- encoding : utf-8 -*-
module EsQuickStatsTechnicalInfo

  def self.get_data
    data = {mysql: Call.count.to_i, es: '-', status: '-'}
    calls_count = Elasticsearch.safe_search_mor_calls({size: 0})

    if calls_count.present? && calls_count['hits']['total'].present?
      data[:es] = calls_count['hits']['total'].to_i
    else
      return data
    end

    data[:status] = (data[:es] >= data[:mysql]) ? 100 : (data[:es].to_f / data[:mysql].to_f * 100).floor

    data
  end
end
