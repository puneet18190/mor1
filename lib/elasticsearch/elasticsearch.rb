# -*- encoding : utf-8 -*-
module Elasticsearch

  require 'net/http'
  require 'uri'
  require 'json'

  def self.search_mor_calls(body = {}, options = {})
    es_ip = Confline.get_value('ES_IP')
    es_ip = 'localhost' if es_ip.blank?

    search_type = case options[:search_type]
                    when false
                      ''
                    else
                      '&search_type=count'
                  end

    uri = URI.parse("http://#{es_ip}:9200/mor/calls/_search?query_cache=true#{search_type}")
    header = {'Content-Type' => 'text/json'}
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = body.to_json
    response = JSON.parse(http.request(request).body)

    elastic_debug(body, response) if Socket.gethostname.to_s.include?('kolmisoft')

    return response
  end

  # All possible ES errors/malfunctions must be escaped here.
  #  if something went wrong, false must be returned.
  #  this method call must always be checked for false return.
  def self.safe_search_mor_calls(body = {}, options = {})
    begin
      response = self.search_mor_calls(body, options)
    rescue
      return false
    end

    if response.try(:[], 'error').present?
      return false
    end

    return response
  end

  private

  def self.elastic_debug(request, response)
    time_now = Time.now
    MorLog.my_debug('++++++++++++++++++++++++++++++++++++++++++++++++++++++')
    MorLog.my_debug("Time now: #{time_now.strftime('%F %H:%M:%S.%L')}")
    MorLog.my_debug('ElasticSearch Query:')
    MorLog.my_debug(JSON.pretty_generate(request))
    MorLog.my_debug("\nResponse:")
    MorLog.my_debug(JSON.pretty_generate(response))
    MorLog.my_debug("\nQuery began at: #{time_now.strftime('%H:%M:%S.%L')}")
    MorLog.my_debug("Time now: #{Time.now.strftime('%H:%M:%S.%L')}")
    MorLog.my_debug("Difference: #{Time.now - time_now}")
    MorLog.my_debug("-----------------------------------------------------\n")
  end
end
