# -*- encoding : utf-8 -*-
module ElasticsearchQueries

  def es_admin_quick_stats_from_users_query(from, till)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: from, lte: till}}},
                            {term: {hangupcause: '16'}},
                            {term: {reseller_id: '0'}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            total_provider_price: {
                sum: {
                    field: 'provider_price'
                }
            },
            total_did_prov_price: {
                sum: {
                    field: 'did_prov_price'
                }
            },
            total_user_price: {
                sum: {
                    field: 'user_price'
                }
            },
            total_did_inc_price: {
                sum: {
                    field: 'did_inc_price'
                }
            },
            total_did_price: {
                sum: {
                    field: 'did_price'
                }
            }
        }
    }
  end

  def es_admin_quick_stats_from_resellers_query(from, till)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: from, lte: till}}},
                            {term: {hangupcause: '16'}},
                            {exists: { field: 'reseller_id' }}
                        ],
                        must_not: [
                            {term: {reseller_id: '0'}},
                            {range: {partner_id: {gt: '0'}}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            total_provider_price: {
                sum: {
                    field: 'provider_price'
                }
            },
            total_did_prov_price: {
                sum: {
                    field: 'did_prov_price'
                }
            },
            total_reseller_price: {
                sum: {
                    field: 'reseller_price'
                }
            },
            total_did_inc_price: {
                sum: {
                    field: 'did_inc_price'
                }
            },
            total_did_price: {
                sum: {
                    field: 'did_price'
                }
            }
        }
    }
  end

  def es_admin_quick_stats_from_partners_query(from, till)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: from, lte: till}}},
                            {term: {hangupcause: '16'}},
                            {exists: { field: 'partner_id' }}
                        ],
                        must_not: [
                            {term: {partner_id: '0'}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            total_provider_price: {
                sum: {
                    field: 'provider_price'
                }
            },
            total_did_prov_price: {
                sum: {
                    field: 'did_prov_price'
                }
            },
            total_partner_price: {
                sum: {
                    field: 'partner_price'
                }
            },
            total_did_inc_price: {
                sum: {
                    field: 'did_inc_price'
                }
            },
            total_did_price: {
                sum: {
                    field: 'did_price'
                }
            }
        }
    }
  end

  def es_reseller_quick_stats_query(from, till, reseller_id)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: "#{from}", lte: "#{till}"}}},
                            {term: {hangupcause: '16'}},
                            {term: {reseller_id: "#{reseller_id}"}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            total_reseller_price: {
                sum: {
                    field: 'reseller_price'
                }
            },
            total_did_inc_price: {
                sum: {
                    field: 'did_inc_price'
                }
            },
            total_user_price: {
                sum: {
                    field: 'user_price'
                }
            }
        }
    }
  end

  def es_user_quick_stats_query(from, till, user_id)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: "#{from}", lte: "#{till}"}}},
                            {term: {hangupcause: '16'}},
                            {term: {user_id: "#{user_id}"}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            user_billsec: {
                sum: {
                    field: 'user_billsec'
                }
            }
        }
    }
  end

  def self.es_hangup_cause_codes_stats_query(from, till, options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: from, lte: till}}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                grouped_by_hgc: {
                    terms: {
                        field: 'hangupcause',
                        order: {_term: 'asc'},
                        size: 0
                    }
                }
            }
        }

    if options[:provider_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {provider_id: "#{options[:provider_id]}"}},
                      {term: {did_provider_id: "#{options[:provider_id]}"}}
                  ]
              }
          }
    end

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: "#{options[:user_id]}"}}
    elsif options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {terms: {user_id: users_array}},
                      {terms: {dst_user_id: users_array}},
                      {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end

    if options[:is_reseller]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {reseller_id: "#{options[:reseller_id]}"}},
                      {term: {dst_user_id: "#{options[:reseller_id]}"}}
                  ]
              }
          }
    end

    if options[:device_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {src_device_id: "#{options[:device_id]}"}},
                      {term: {dst_device_id: "#{options[:device_id]}"}}
                  ]
              }
          }
    end

    return query
  end

  def self.es_hangup_cause_codes_stats_calls_query(from, till, options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: from, lte: till}}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                dates: {
                    date_histogram: {
                        field: 'calldate',
                        interval: 'day',
                        time_zone: options[:utc_offset],
                        format: 'yyyy-MM-dd'
                    }
                }
            }
        }

    if options[:good_calls]
      query[:query][:filtered][:filter][:bool][:must] << {term: {hangupcause: '16'}}
    elsif options[:bad_calls]
      query[:query][:filtered][:filter][:bool][:must] << {exists: {field: 'hangupcause'}}
      query[:query][:filtered][:filter][:bool].store(:must_not, [{term: {hangupcause: '16'}}])
    end

    if options[:provider_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {provider_id: "#{options[:provider_id]}"}},
                      {term: {did_provider_id: "#{options[:provider_id]}"}}
                  ]
              }
          }
    end

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: "#{options[:user_id]}"}}
    elsif options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {terms: {user_id: users_array}},
                      {terms: {dst_user_id: users_array}},
                      {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end

    if options[:is_reseller]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {reseller_id: "#{options[:reseller_id]}"}},
                      {term: {dst_user_id: "#{options[:reseller_id]}"}}
                  ]
              }
          }
    end

    if options[:device_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {src_device_id: "#{options[:device_id]}"}},
                      {term: {dst_device_id: "#{options[:device_id]}"}}
                  ]
              }
          }
    end

    return query
  end

  def self.es_all_users_detailed_calls_query(from, till, users = [], user_perspective = false)
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: from, lte: till}}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            outgoing_calls_filter: {
                filter: {range: {user_id: {gt: -1 }}},
                aggregations: {
                    grouped_by_disposition: {
                        terms: {
                            field: "disposition",
                            size: 0
                        }
                    }
                }
            },
            incoming_calls_filter: {
                filter: {term: {user_id: -1 }},
                aggregations: {
                    grouped_by_disposition: {
                        terms: {
                            field: "disposition",
                            size: 0
                        }
                    }
                }
            }
        }
    }
    if users.present?
        query[:aggregations][:outgoing_calls_filter][:filter] = {terms: {user_id: users}}
        query[:aggregations][:incoming_calls_filter][:filter] = {terms: {dst_user_id: users}}
        query[:query][:filtered][:filter][:bool][:should] = [{terms: {user_id: users}}, {terms: {dst_user_id: users}}]
    end
    query[:query][:filtered][:filter][:bool][:must] << { term: { user_perspective: 1 } } if user_perspective

    query
  end

  def self.es_answered_calls_day_by_day(from, till, options = {}, users = [])
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: from, lte: till}}},
                            {term: {hangupcause: "16"}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            dates: {
                date_histogram: {
                    field: "calldate",
                    interval: "day",
                    time_zone: options[:utc_offset],
                    format: "yyyy-MM-dd"
                },
                aggregations: {
                    total_billsec: {
                        sum: {
                            field: "billsec"
                        }
                    }
                }
            }
        }
    }
    if users.present?
        query[:query][:filtered][:filter][:bool][:should] = [{terms: {user_id: users}}, {terms: {dst_user_id: users}}]
    end
    query
  end

  def self.es_aggregates(from, till, options)
    query_filter = [
        { range: { calldate: { gte: from, lte: till } } }
    ]


    if options[:originator_id].to_i > 0
        query_filter << {term: { user_id: options[:originator_id] } }
    end

    if options[:country].to_i > 0
        query_filter << {term: { destinationgroup_id: options[:country] } }
    end

    aggregations = {
        aggregations: {
            total_billsec: {
                sum: {
                    field: "billsec"
                }
            },
            total_originator_billsec: {
                sum: {
                    field: "user_billsec"
                }
            },
            total_terminator_billsec: {
                sum: {
                    field: "provider_billsec"
                }
            },
            total_terminator_price: {
                sum: {
                    field: "provider_price"
                }
            },
            total_originator_price: {
                sum: {
                    field: "user_price"
                }
            },
            answered_calls: {
                filter: {
                    term: {
                        hangupcause: "16"
                    }

                }
            }
        }
    }

    if options[:prefix].present?
        aggregations = {
            aggregations: {
                grouped_by_prefix: {
                    terms: {
                        field: "prefix",
                        order: { _term: "asc" },
                        size: 0
                    },
                    aggregations: aggregations[:aggregations]
                }
            }
        }
    end

    if options[:terminator].to_i >= 0
        query_filter << {terms: { provider_id: options[:provider_ids] } } if options[:provider_ids].present?
        aggregations = {
            aggregations: {
                grouped_by_terminator: {
                    terms: {
                        field: "provider_id",
                        order: { _term: "asc" },
                        size: 0
                    },
                    aggregations: aggregations[:aggregations]
                }
            }
        }
    end

    if options[:originator_id] != 'none'
        aggregations = {
            aggregations: {
                grouped_by_originator: {
                    terms: {
                        field: "user_id",
                        order: { _term: "asc" },
                        size: 0
                    },
                    aggregations: aggregations[:aggregations]
                }
            }
        }
    end

    if options[:country] != '-1'
        aggregations = {
            aggregations: {
                grouped_by_dg_id: {
                    terms: {
                        field: 'destinationgroup_id',
                        order: {_term: 'asc'},
                        size: 0
                    },
                    aggregations: aggregations[:aggregations]
                }
            }
        }
    end

    query = {
        from: options[:fpage], size: options[:items_per_page],
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: query_filter
                    }
                }
            }
        },
        sort: [
            { billsec: "asc" }
        ],
        aggregations: aggregations[:aggregations]
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}},
                    {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end

    if options[:prefix].present?
        query[:query][:filtered][:query] = { wildcard: { prefix: options[:prefix].gsub('%', '*') } }
    end

    query
  end

  def self.country_stats_query(options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                                {term: {hangupcause: '16'}},
                                {exists: {field: 'prefix'}}
                            ],
                            must_not: [
                                {term: {prefix: ''}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                grouped_by_dg_id: {
                    terms: {
                        field: 'destinationgroup_id',
                        order: {_term: 'asc'},
                        size: 0
                    },
                    aggregations: {
                        total_billsec: {
                            sum: {
                                field: 'billsec'
                            }
                        },
                        total_provider_price: {
                            sum: {
                                field: 'provider_price'
                            }
                        },
                        total_user_price: {
                            sum: {
                                field: 'user_price'
                            }
                        },
                        total_reseller_price: {
                            sum: {
                                field: 'reseller_price'
                            }
                        },
                        total_did_inc_price: {
                            sum: {
                                field: 'did_inc_price'
                            }
                        }
                    }
                }
            }
        }

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: "#{options[:user_id]}"}}
    elsif options[:show_only_assigned_users].to_i == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}},
                    {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end

    if options[:is_reseller]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {reseller_id: "#{options[:reseller_id]}"}},
                      {term: {user_id: "#{options[:reseller_id]}"}},
                      {term: {dst_user_id: "#{options[:reseller_id]}"}}
                  ]
              }
          }
    end

    query
  end

  def self.calls_per_day(options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                dates: {
                    date_histogram: {
                        field: 'calldate',
                        interval: 'day',
                        time_zone: options[:utc_offset],
                        #time_zone: '-09:00',
                        format: 'yyyy-MM-dd'
                    },
                    aggregations: {
                        answered_calls: {
                            filter: {
                                term: {
                                    hangupcause: '16'
                                }
                            },
                            aggregations: {
                                total_billsec: {
                                    sum: {
                                        field: 'billsec'
                                    }
                                },
                                total_partner_price: {
                                    sum: {
                                        field: 'partner_price'
                                    }
                                },
                                total_reseller_price: {
                                    filter: {},
                                    aggregations: {
                                        reseller_price_admin_provider: {
                                            filter: {
                                                terms: {
                                                    provider_id: options[:admin_providers]
                                                }
                                            },
                                            aggregations: {
                                                reseller_price: {
                                                    sum: {
                                                        field: 'reseller_price'
                                                    }
                                                }
                                            }
                                        },
                                        did_inc_price: {
                                            sum: {
                                                field: 'did_inc_price'
                                            }
                                        }
                                    }
                                },
                                total_provider_price: {
                                    filter: {},
                                    aggregations: {
                                        provider_price_admin_provider: {
                                            filter: {
                                                terms: {
                                                    provider_id: options[:admin_providers]
                                                }
                                            },
                                            aggregations: {
                                                provider_price: {
                                                    sum: {
                                                        field: 'provider_price'
                                                    }
                                                }
                                            }
                                        },
                                        did_prov_price: {
                                            sum: {
                                                field: 'did_prov_price'
                                            }
                                        }
                                    }
                                },
                                total_user_price_reseller: {
                                    filter: {
                                        range: {
                                            reseller_id: {gt: 0}
                                        }
                                    },
                                    aggregations: {
                                        user_price_admin_provider: {
                                            filter: {
                                                terms: {
                                                    provider_id: options[:admin_providers]
                                                }
                                            },
                                            aggregations: {
                                                reseller_price: {
                                                    sum: {
                                                        field: 'reseller_price'
                                                    }
                                                }
                                            }
                                        },
                                        did_inc_price: {
                                            sum: {
                                                field: 'did_inc_price'
                                            }
                                        }
                                    }
                                },
                                total_user_price_admin: {
                                    filter: {
                                        term: {
                                            reseller_id: '0'
                                        }
                                    },
                                    aggregations: {
                                        user_price: {
                                            sum: {
                                                field: 'user_price'
                                            }
                                        },
                                        did_inc_price: {
                                            sum: {
                                                field: 'did_inc_price'
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }


    if options[:provider_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {provider_id: "#{options[:provider_id]}"}},
                      {term: {did_provider_id: "#{options[:provider_id]}"}}
                  ]
              }
          }
    end

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: "#{options[:user_id]}"}}
    end

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}},
                    {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end

    if options[:reseller_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {reseller_id: "#{options[:reseller_id]}"}}
    end

    if options[:partner_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {partner_id: "#{options[:partner_id]}"}}
    end

    if options[:destination_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destination_group_id]}"}}
    end

    return query
  end

  def self.calls_system_stats(options)
    query = {
        size: 0,
          query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                            ]
                        }
                    }
                }
            },
        aggregations: {
            answered: {
                filter: {
                    term: {
                        disposition: 'ANSWERED'
                    }
                }
            },
            busy: {
                filter: {
                    term: {
                        disposition: 'BUSY'
                    }
                }
            },
            no_answer: {
                filter: {
                    term: {
                        disposition: 'NO ANSWER'
                    }
                }
            }
        }
    }
    if options[:show_assign_users]
      users_array = options[:users_array]
      resellers_array = options[:resellers_array]
      query[:query][:filtered][:filter][:bool][:must] =
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}},
                    {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end
    return query
  end

  def self.calls_by_user(options)
    current_user = options[:current_user]
    prov_price = current_user.is_reseller? ? 'reseller_price' : 'provider_price'

    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: { calldate: { gte: options[:gte], lte: options[:lte] }}},
                            {terms: { user_id: options[:user_id] }}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_user_id: {
                terms: {
                    field: 'user_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        'filter' => {term: {hangupcause: '16'}},
                        aggregations: {
                            total_billsec: {
                                sum: {
                                    field: 'billsec'
                                }
                            },
                            total_provider_price: {
                                sum: {
                                    field: "#{prov_price}"
                                }
                            },
                            total_user_price: {
                                sum: {
                                    field: 'user_price'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.calls_by_user_reseller(options)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: { calldate: { gte: options[:gte], lte: options[:lte] }}},
                            {terms: { reseller_id: options[:reseller_id] }}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_reseller_id: {
                terms: {
                    field: 'reseller_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        'filter' => {term: {hangupcause: '16'}},
                        aggregations: {
                            total_billsec: {
                                sum: {
                                    field: 'billsec'
                                }
                            },
                            total_provider_price: {
                                sum: {
                                    field: 'provider_price'
                                }
                            },
                            total_user_price: {
                                sum: {
                                    field: 'reseller_price'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.calls_by_user_partner(options)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: { calldate: { gte: options[:gte], lte: options[:lte] }}},
                            {terms: { partner_id: options[:partner_id] }}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_partner_id: {
                terms: {
                    field: 'partner_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        'filter' => {term: {hangupcause: '16'}},
                        aggregations: {
                            total_billsec: {
                                sum: {
                                    field: 'billsec'
                                }
                            },
                            total_provider_price: {
                                sum: {
                                    field: 'provider_price'
                                }
                            },
                            total_user_price: {
                                sum: {
                                    field: 'partner_price'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.loss_making_calls(options = {})
    query =
        {
            size: 10000,
            fields: [
                'id',
                'calldate',
                'dst',
                'prefix',
                'billsec',
                'user_rate',
                'provider_rate',
                'user_price',
                'did_inc_price',
                'provider_price',
                'did_prov_price',
                'user_id',
                'src_device_id',
            ],
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                                {term: {hangupcause: '16'}},
                                {range: {user_billsec: {gt: '0'}}},
                                {script: {script: "doc['provider_price'].value > doc['user_price'].value"}}
                            ]
                        }
                    }
                }
            },
            sort: {calldate: 'desc'},
            aggregations: {
                total_billsec: {
                    sum: {
                        field: 'billsec'
                    }
                },
                total_provider_price: {
                    sum: {
                        field: 'provider_price'
                    }
                },
                total_did_prov_price: {
                    sum: {
                        field: 'did_prov_price'
                    }
                },
                total_user_price: {
                    sum: {
                        field: 'user_price'
                    }
                },
                total_did_inc_price: {
                    sum: {
                        field: 'did_inc_price'
                    }
                }
            }
        }


    if options[:reseller_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {reseller_id: "#{options[:reseller_id]}"}}
    elsif options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
        {
            bool: {
                should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}},
                    {terms: {reseller_id: resellers_array}}
                ]
            }
        }
    end

    return query
  end

  def self.dids_stats(options = {})
    query =
    {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {
                                range: {
                                    calldate: {
                                        gte: options[:from],
                                        lte: options[:till]
                                    }
                                }
                            },
                            {
                                range: {
                                    did_id: {
                                        gt: 0
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_did_id: {
                terms: {
                    field: 'did_id',
                    size: 0
                },
                aggregations: {
                    total_did_inc_price: {
                        sum: {
                            field: 'did_inc_price'
                        }
                    },
                    total_did_price: {
                        sum: {
                            field: 'did_price'
                        }
                    },
                    total_did_prov_price: {
                        sum: {
                            field: 'did_prov_price'
                        }
                    }
                }
            }
        }
    }
    query
  end

  def self.generate_invoice_by_cid_cs(options = {})
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: { calldate: { gte: options[:from], lte: options[:till] }}},
                            {term: {hangupcause: 16}},
                            {term: {card_id: 0}},
                            {range: {billsec: {gt: 0}}}
                        ],
                        should: [
                            {terms: {dst_device_id: options[:device_id]}},
                            {terms: {src_device_id: options[:device_id]}}

                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_src: {
                terms: {
                    field: 'src',
                    order: {_term: 'asc'},
                    size: 0
                },
                aggregations: {
                    total_reseller_price: {
                        filter: {
                            range: {reseller_id: {gt: 0}}
                        },
                        aggregations: {
                            provider_agg: {
                                filter: {
                                    terms: {provider_id: options[:admin_providers]}
                                },
                                aggregations: {
                                    reseller_price: {
                                        sum: {field: 'reseller_price'}
                                    }
                                }
                            }
                        }
                    },
                    total_user_price:{
                        filter: {},
                        aggregations: {
                            user_price: {
                                sum:{field: 'user_price'}
                            }
                        }
                    },
                    total_did_inc_price: {
                        sum: {field: 'did_inc_price'}
                    },
                    total_partner_price:{
                        filter: {
                            range: {partner_id: {gt: 0}}
                        },
                        aggregations: {
                            partner_price: {
                                sum:{field: 'partner_price'}
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.stats_by_provider(options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                                {
                                    terms: (options[:did_provider] ? {did_provider_id: options[:providers_id]} : {provider_id: options[:providers_id]})
                                }
                            ]
                        }
                    }
                }
            },
            aggregations: {
                group_by_provider_id: {
                    terms: {
                        field: (options[:did_provider] ? 'did_provider_id' : 'provider_id'),
                        size: 0
                    },
                    aggregations: {
                        answered_calls: {
                            filter: {term: {hangupcause: '16'}},
                            aggregations: {
                                total_provider_billsec: {
                                    sum: {field: 'provider_billsec'}
                                },
                                total_provider_price: {
                                    sum: {field: 'provider_price'}
                                },
                                total_reseller_price: {
                                    sum: {field: 'reseller_price'}
                                },
                                total_sell_price_admin_reseller_price: {
                                    filter: {range: {reseller_id: {gt: 0}}},
                                    aggregations: {
                                        reseller_price: {
                                            sum: {field: 'reseller_price'}
                                        }
                                    }
                                },
                                total_sell_price_admin_user_price: {
                                    filter: {term: {reseller_id: 0}},
                                    aggregations: {
                                        user_price: {
                                            sum: {field: 'user_price'}
                                        },
                                    }
                                },
                                total_sell_price_reseller: {
                                    sum: {field: 'user_price'}
                                }
                            }
                        },
                        no_answer: {
                            filter: {term: {disposition: 'NO ANSWER'}}
                        },
                        busy: {
                            filter: {term: {disposition: 'BUSY'}}
                        },
                        failed: {
                            filter: {
                                bool: {
                                    should: [
                                        {
                                            bool: {
                                                must: [
                                                    {range: {hangupcause: {lt: 200}}},
                                                    {term: {disposition: 'FAILED'}}
                                                ]
                                            }
                                        },
                                        {
                                            bool: {
                                                must: [
                                                    {range: {hangupcause: {lt: 200}}},
                                                    {term: {disposition: 'ANSWERED'}}
                                                ],
                                                must_not: [
                                                    {term: {hangupcause: 16}}
                                                ]
                                            }
                                        }
                                    ]
                                }
                            }
                        },
                        failed_locally: {
                            filter: {
                                bool: {
                                    must: [
                                        {range: {hangupcause: {gt: 199}}}
                                    ],
                                    should: [
                                        {term: {disposition: 'ANSWERED'}},
                                        {term: {disposition: 'FAILED'}}
                                    ]
                                }
                            }
                        }
                    }
                }
            }
        }

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:is_reseller]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {reseller_id: "#{options[:user_id]}"}},
                      {term: {user_id: "#{options[:user_id]}"}}
                  ]
              }
          }
    end

    query
  end

  def self.provider_stats(options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                                {
                                    term: (options[:did_provider] ? {did_provider_id: options[:provider_id]} : {provider_id: options[:provider_id]})
                                }
                            ]
                        }
                    }
                }
            },
            aggregations: {
                answered_calls: {
                    filter: {
                        bool: {
                            must: [
                                    {term: {hangupcause: 16}}
                            ],
                            must_not: [
                                    {term: {disposition: 'BUSY'}}
                            ]
                        }
                    }
                },
                no_answer: {
                    filter: {term: {disposition: 'NO ANSWER'}}
                },
                busy: {
                    filter: {term: {disposition: 'BUSY'}}
                },
                failed: {
                    filter: {
                        bool: {
                            should: [
                                {
                                    bool: {
                                        must: [
                                            {range: {hangupcause: {lt: 200}}},
                                            {term: {disposition: 'FAILED'}}
                                        ]
                                    }
                                },
                                {
                                    bool: {
                                        must: [
                                            {range: {hangupcause: {lt: 200}}},
                                            {term: {disposition: 'ANSWERED'}}
                                        ],
                                        must_not: [
                                            {term: {hangupcause: 16}}
                                        ]
                                    }
                                }
                            ]
                        }
                    }
                },
                failed_locally: {
                    filter: {
                        bool: {
                            must: [
                                {range: {hangupcause: {gt: 199}}}
                            ],
                            should: [
                                {term: {disposition: 'ANSWERED'}},
                                {term: {disposition: 'FAILED'}}
                            ]
                        }
                    }
                }
            }
        }

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:is_reseller]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {reseller_id: "#{options[:user_id]}"}},
                      {term: {user_id: "#{options[:user_id]}"}}
                  ]
              }
          }
    end
    query
  end

  def self.profit(options = {})
    current_user_type = options[:usertype]
    search_user_type = options[:s_usertype]
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                for_all: {
                    filter: {},
                aggregations: {
                    answered: {
                        filter: {term: { disposition: 'ANSWERED'}},
                                aggregations: {
                                    succesfull: {
                                        filter: {term: {hangupcause: 16}},
                                            aggregations: {
                                                billsec_not_nul: {
                                                    filter: {range: {billsec: {gt: 0}}},
                                                        aggregations:{
                                                            billsec: {
                                                                sum: {field: 'billsec'}
                                                            }
                                                        }
                                                },
                                                billsec_nul: {
                                                    filter: {term: {billsec: 0}},
                                                        aggregations:{
                                                            real_billsec: {
                                                                sum: {field: 'real_billsec'}
                                                            }
                                                        }
                                                }
                                            }
                                    },
                                    total_reseller_billsec: {
                                        sum: {field: 'reseller_billsec'}
                                    },
                                    total_provider_price: {
                                        sum: {field: 'provider_price'}
                                    },
                                    total_did_prov_price: {
                                        sum: {field: 'did_prov_price'}
                                    },
                                    total_did_inc_price: {
                                        sum: {field: 'did_inc_price'}
                                    },
                                    total_did_price: {
                                        sum: {field: 'did_price'}
                                    },
                                    total_reseller_price: {
                                        sum: {field: 'reseller_price'}
                                    },
                                    total_partner_price: {
                                        sum: {field: 'partner_price'}
                                    },
                                    total_user_price: {
                                        sum: {field: 'user_price'}
                                    },
                                    total_users: {
                                        cardinality: {field: 'user_id'}
                                    },
                                    total_users_for_admin: {
                                        filter: {
                                            bool: {
                                                must: [
                                                    {range: {user_id: {gt: 0}}}
                                                ],
                                                must_not: [
                                                    {range: {partner_id: {gt: 0}}},
                                                    {range: {reseller_id: {gt: 0}}}
                                                ]
                                            }
                                        },
                                        aggregations: {
                                            total_users_for_admin_value:{
                                                cardinality: {field: 'user_id'}
                                            }
                                        }
                                    },
                                    total_resellers: {
                                        cardinality: {field: 'reseller_id'}
                                    },
                                    total_resellers_for_admin: {
                                        filter: {
                                            bool: {
                                                must: [
                                                    {range: {reseller_id: {gt: 0}}}
                                                ],
                                                must_not: [
                                                    {range: {partner_id: {gt: 0}}}
                                                ]
                                            }
                                        },
                                        aggregations: {
                                            total_resellers_for_admin_value:{
                                                cardinality: {field: 'reseller_id'}
                                            }
                                        }
                                    },
                                    total_partners_for_admin: {
                                        filter: {
                                            bool: {
                                                must: [
                                                    {range: {partner_id: {gt: 0}}}
                                                ]
                                            }
                                        },
                                        aggregations: {
                                            total_partners_for_admin_value:{
                                                cardinality: {field: 'partner_id'}
                                            }
                                        }
                                    },
                                    total_reseller_prices_for_admin: {
                                        filter: {
                                            bool: {
                                                must: [
                                                    {range: {reseller_id: {gt: 0}}}
                                                ],
                                                must_not: [
                                                    {range: {partner_id: {gt: 0}}}
                                                ]
                                            }
                                        },
                                        aggregations: {
                                            reseller_price_for_admin:{
                                              sum: {field: 'reseller_price'}
                                            }
                                        }
                                    },
                                    total_user_prices_for_admin: {
                                         filter: {term: {reseller_id:  0}},
                                            aggregations: {
                                                user_price_for_admin:{
                                                  sum: {field: 'user_price'}
                                                }
                                            }
                                    },
                                }
                    },
                    busy: {
                        filter: {
                            term: {
                                disposition: 'BUSY'
                            }
                        }
                    },
                    no_answer: {
                        filter: {
                            term: {
                                disposition: 'NO ANSWER'
                            }
                        }
                    },
                    failed: {
                        filter: {
                            term: {
                                disposition: 'FAILED'
                            }
                        }
                    }

              }
                },
                for_user: {
                    filter: {},
                        aggregations:{
                            total_did_price_for_user: {
                                    sum: {field: 'did_price'}
                            }
                        }
                }
        }
      }

    if current_user_type == 'reseller'
        query[:aggregations][:for_all][:filter] = {term: {reseller_id: options[:current_user_id]}}
    elsif current_user_type == 'partner'
        query[:aggregations][:for_all][:filter] = {bool: {must: [{term: {partner_id: options[:current_user_id]}}]}}
    end

    if options[:user_id]
        if search_user_type == 'reseller' &&  current_user_type == 'partner'
            query[:aggregations][:for_all][:filter][:bool][:must] << {terms: {reseller_id: options[:user_id]}}
        elsif search_user_type == 'partner'
            query[:aggregations][:for_all][:filter] = {terms: {reseller_id: options[:user_id]}}
        else
            query[:aggregations][:for_all][:filter] =
                {
                    bool: {
                        should: [
                            {terms: {user_id: options[:user_id]}},
                            {terms: {reseller_id: options[:user_id]}},
                            {terms: {partner_id: options[:user_id]}}
                        ]
                    }
                }
        end
        query[:aggregations][:for_user][:filter] = {terms: {dst_user_id: options[:user_id]}}
    end
    return query
  end

  def self.dids_summary(options = {})
    query =
    {
        query: {
            filtered: {
                filter: {
                    bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                                {terms: {did_provider_id: options[:providers_id]}}
                            ],
                            must_not: []
                    }
                }
            }
        },
        aggregations: {
            group_by_provider_id: {
                terms: {
                    field: (options[:dids_grouping] == 1 ? 'did_provider_id' : 'did_id'),
                    size: 0
                },
                aggregations: {
                    total_did_billsec: {
                        sum: {
                            field: 'did_billsec'
                        }
                    },
                    total_did_price: {
                        sum: {
                            field: 'did_price'
                        }
                    },
                    total_did_prov_price: {
                        sum: {
                            field: 'did_prov_price'
                        }
                    },
                    total_did_inc_price: {
                        sum: {
                            field: 'did_inc_price'
                        }
                    }
                }
            }
        }
    }
    if options[:dids_grouping] == 2
      query[:query][:filtered][:filter][:bool][:must] << {terms: {did_id: options[:dids_id]}}
    end

    if options[:did_id_params].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {did_id: options[:did_id_params]}}
    end

    if options[:did_id_range].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {did_id: options[:did_id_range]}}
    end

    if options[:did_provider_id].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {did_provider_id: options[:did_provider_id]}}
    end

    if options[:s_by_user_id].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {did_id: options[:s_by_user_id]}}
    end

    if options[:s_by_device_id].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {did_id: options[:s_by_device_id]}}
    end

    if options[:s_days].present?
        if options[:s_days].to_s == 'fd'
            query[:query][:filtered][:filter][:bool][:must] << {script: {script: "doc['calldate'].date.dayOfWeek == 7 || doc['calldate'].date.dayOfWeek == 6"}}
        else
            query[:query][:filtered][:filter][:bool][:must_not] << {script: {script: "doc['calldate'].date.dayOfWeek == 7 || doc['calldate'].date.dayOfWeek == 6"}}
        end
    end
     if options[:rate_start].present?
        query[:query][:filtered][:filter][:bool][:must] << {script:
                                                                {script: "doc.calldate.date.getSecondOfDay() >= min && doc.calldate.date.getSecondOfDay() <= max",
                                                                    params: {
                                                                        min: options[:rate_start],
                                                                        max: options[:rate_end]
                                                                    }
                                                                }
                                                            }
    end
    query
  end

  def self.calls_per_hour_by_date(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_date: {
                date_histogram: {
                    field: 'calldate',
                    interval: 'day',
                    time_zone: options[:utc_offset],
                    format: 'yyyy-MM-dd'
                },
                aggregations: {
                    user_perspective: {
                        filter: {term: {user_perspective: 1}}
                    },
                    answered_calls: {
                        filter: {term: {hangupcause: '16'}}
                    },
                    total_billsec: {
                        sum: {field: 'billsec'}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}}
                  ]
              }
          }
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: options[:user]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: {user_id: {gt: 0}}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    query
  end

  def self.calls_per_hour_by_originator(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_user_id: {
                terms: {
                    field: 'user_id',
                    size: 0
                },
                aggregations: {
                    user_perspective: {
                        filter: {term: {user_perspective: 1}}
                    },
                    answered_calls: {
                        filter: {term: {hangupcause: '16'}}
                    },
                    total_billsec: {
                        sum: {field: 'billsec'}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}}
                  ]
              }
          }
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: options[:user]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: {user_id: {gt: 0}}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    query
  end

  def self.calls_per_hour_by_hour(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_hour: {
                date_histogram: {
                    field: 'calldate',
                    interval: 'hour',
                    time_zone: options[:utc_offset],
                    format: 'H'
                },
                aggregations: {
                    user_perspective: {
                        filter: {term: {user_perspective: 1}}
                    },
                    answered_calls: {
                        filter: {term: {hangupcause: '16'}}
                    },
                    total_billsec: {
                        sum: {field: 'billsec'}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}}
                  ]
              }
          }
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: options[:user]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: {user_id: {gt: 0}}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    query
  end

  def self.calls_per_hour_by_destination(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_prefix: {
                terms: {
                    field: 'prefix',
                    size: 0
                },
                aggregations: {
                    user_perspective: {
                        filter: {term: {user_perspective: 1}}
                    },
                    answered_calls: {
                        filter: {term: {hangupcause: '16'}}
                    },
                    total_billsec: {
                        sum: {field: 'billsec'}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}}
                  ]
              }
          }
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: options[:user]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: {user_id: {gt: 0}}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    query
  end

  def self.calls_per_hour_by_terminator(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_provider_id: {
                terms: {
                    field: 'provider_id',
                    size: 0
                },
                aggregations: {
                    user_perspective: {
                        filter: {term: {user_perspective: 1}}
                    },
                    answered_calls: {
                        filter: {term: {hangupcause: '16'}}
                    },
                    total_billsec: {
                        sum: {field: 'billsec'}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}}
                  ]
              }
          }
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: options[:user]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: {user_id: {gt: 0}}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    query
  end

  def self.aggregates(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}}
                        ]
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      users_array = options[:user_array]
      resellers_array = options[:reseller_array]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                    {terms: {user_id: users_array}},
                    {terms: {dst_user_id: users_array}},
                    {terms: {reseller_id: resellers_array}}
                  ]
              }
          }
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: options[:user]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: {user_id: {gt: 0}}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix].present?
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:destinationgroup_id].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destinationgroup_id]}"}}
    end

    if options[:group_by].any? { |h| ['agg_by_dg', 'agg_by_dg'].include?(h[:group_name]) }
      query[:query][:filtered][:filter][:bool][:must] << {exists: {field: 'prefix'}}
      query[:query][:filtered][:filter][:bool][:must_not] = [{term: {prefix: ''}}]
    end

    if options[:user_perspective].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_perspective: 1}}
    end

    if options[:group_by].any?  { |h| h[:group_name] == 'agg_by_provider' }
       query[:query][:filtered][:filter][:bool][:must] << {range: {provider_id: {gt: 0}}}
    end

    agg_by_answered = {
        agg_by_answered: {
            filter: {term: {hangupcause: 16}},
            aggregations: {
                total_originator_price: {
                    sum: {field: 'user_price'}
                },
                total_billsec: {
                    sum: {field: options[:use_real_billsec].present? ? 'real_billsec' :'billsec'}
                },
                total_originator_billsec: {
                    sum: {field: 'user_billsec'}
                },
                total_terminator_billsec: {
                    sum: {field: 'provider_billsec'}
                },
                total_terminator_price: {
                    sum: {field: 'provider_price'}
                }
            }
        }
    }

    options[:group_by].each_with_index do |group_by, index|
      aggregation = {
          group_by[:group_name] => {
              terms: {
                  field: group_by[:group_field],
                  size: 0
              }
          }
      }

      case index
        when 0
          query[:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations] = agg_by_answered
        when 1
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations] = agg_by_answered
        when 2
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations] = agg_by_answered
        when 3
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations][options[:group_by][3][:group_name]][:aggregations] = agg_by_answered
      end
    end

    query
  end

  def self.last_calls_totals_admin(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            { range: { calldate: { gte: options[:from], lte: options[:till] } } }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Total price from Providers.
            total_provider_price: {
                sum: { field: :provider_price }
            },
            # Total price from Resellers.
            total_reseller_price: {
                sum: { field: :reseller_price }
            },
            # Total price from Users.
            total_user_price: {
                sum: { field: :user_price }
            },
            # Total DID incoming price.
            total_did_inc_price: {
                sum: { field: :did_inc_price }
            },
            # Total DID Provider price.
            total_did_prov_price: {
                sum: { field: :did_prov_price }
            },
            # Total DID owner price.
            total_did_price: {
                sum: { field: :did_price }
            },
            # Total duration in seconds.
            total_duration: {
                sum: {
                    script: 'doc.billsec.value == 0 && doc.real_billsec.value > 1 ? Math.ceil(doc.real_billsec.value) : doc.billsec.value'
                }
            },
            # Profit generated by Users.
            calls_by_users: {
                # Aggregate only the Calls where reseller_id = 0.
                filter: { term: { reseller_id: 0 } },
                aggregations: {
                    total_profit_from_users: {
                        sum: { field: :user_price }
                    }
                }
            },
            # Profit generated by Partners.
            calls_by_partners: {
                # Aggregate only the Calls where partner_id > 0.
                filter: { range: { partner_id: { gt: 0 } } },
                aggregations: {
                    total_profit_from_partners: {
                        sum: { field: :partner_price }
                    }
                }
            },
            # Profit generated by Resellers.
            non_partner_calls: {
                # Aggregate only the Calls where partner_id = 0.
                filter: { term: { partner_id: 0 } },
                aggregations: {
                    # Aggregate only the Calls where reseller_id > 0.
                    calls_by_resellers: {
                        filter: { range: { reseller_id: { gt: 0 } } },
                        aggregations: {
                            # Profit generated by all Resellers.
                            total_profit_from_resellers: {
                                sum: { field: :reseller_price }
                            },
                            # Profit generated by Reseller PROs through their own
                            #   Providers. We will need to subtract this amount later.
                            calls_by_rspros: {
                                # Aggregate only the Calls by Reseller PROs' Providers.
                                filter: { terms: { provider_id: options[:rspro_prov_ids] } },
                                aggregations: {
                                    total_rspro_profit: {
                                        sum: { field: :reseller_price }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            # Expense generated by Reseller PROs' Providers.
            #   We will count this as profit in Admin's Provider expense.
            calls_by_rspros: {
                filter: { terms: { provider_id: options[:rspro_prov_ids] } },
                aggregations: {
                    total_rspro_provider_price: {
                        sum: { field: :provider_price }
                    },
                    total_rspro_price: {
                        sum: { field: :reseller_price }
                    }
                }
            }
        }
    }
    # Responsible Accountant filter (because of similarities added to the Admin's query).
    if options[:usertype] == :accountant && options[:resp_acc_user_ids].present?
        query[:query][:filtered][:filter][:bool][:must] << {
            bool: {
                # Filter only the Calls related to the Users the Accountant is responsible for.
                should: [
                    { terms: { user_id: options[:resp_acc_user_ids] } },
                    { terms: { dst_user_id: options[:resp_acc_user_ids] } },
                    { terms: { reseller_id: options[:resp_acc_user_ids] } },
                    { terms: { src_device_id: options[:resp_acc_device_ids] } },
                    { terms: { dst_device_id: options[:resp_acc_device_ids] } }
                ]
            }
        }
    end
    # Filter the result due to the search.
    last_calls_filter(query, options)
  end

  def self.last_calls_totals_reseller(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            { range: {calldate: { gte: options[:from], lte: options[:till]}} },
                            {
                                bool: {
                                    # Filter only the Calls related to a current Reseller.
                                    should: [
                                        { term: { reseller_id: options[:current_user][:id] } },
                                        { terms: { user_id: options[:user_ids] + [options[:current_user][:id]] } },
                                        { terms: { dst_user_id: options[:user_ids] } }
                                    ]
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Total price from Users.
            total_user_price: {
                sum: { field: :user_price }
            },
            # Total price from Resellers.
            total_reseller_price: {
                sum: { field: :reseller_price }
            },
            # Total DID Provider price.
            total_did_prov_price: {
                sum: { field: :did_prov_price }
            },
            # Total DID incoming price.
            calls_by_owned_users: {
                # We only add DID incoming price from Calls made by Reseller owned Users.
                filter: { terms: { user_id: options[:user_ids] } },
                aggregations: {
                    total_did_inc_price: {
                        sum: { field: :did_inc_price }
                    }
                }
            },
            # Total DID owner price.
            calls_not_by_owned_users: {
                # We only add DID incoming price from Calls made by Reseller NOT owned Users.
                filter: { not: { terms: { user_id: options[:user_ids] } } },
                aggregations: {
                    total_did_price: {
                        sum: { field: :did_price }
                    }
                }
            },
            # Total duration in seconds.
            total_duration: {
                sum: {
                    script: 'doc.billsec.value == 0 && doc.real_billsec.value > 1 ? Math.ceil(doc.real_billsec.value) : doc.billsec.value'
                }
            },
            # Expense generated by Reseller PROs' Providers. Used for profit adjustments
            calls_by_rspros: {
                filter: {
                    terms: { provider_id: options[:rspro_prov_ids] }
                },
                aggregations: {
                    total_rspro_provider_price: {
                        sum: { field: :provider_price }
                    },
                    total_rspro_price: {
                        sum: { field: :reseller_price }
                    }
                }
            }
        }
    }
    # Filter the result due to the search.
    last_calls_filter(query, options)
  end

  def self.last_calls_totals_partner(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            { range: { calldate: { gte: options[:from], lte: options[:till] } } }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Total price from Users.
            total_user_price: {
                sum: { field: :user_price }
            },
            # Total price from Partners.
            total_partner_price: {
                sum: { field: :partner_price }
            },
            # Total price from Resellers.
            total_reseller_price: {
                sum: { field: :reseller_price }
            },
            # Total duration in seconds.
            total_duration: {
                sum: {
                    script: 'Math.ceil(doc.partner_billsec.value)'
                }
            },
            # Expense generated by Reseller PROs' Providers. Used for profit adjustments.
            calls_by_rspros: {
                filter: {
                    terms: { provider_id: options[:rspro_prov_ids] }
                },
                aggregations: {
                    total_rspro_partner_price: {
                        sum: { field: :partner_price }
                    },
                    total_rspro_provider_price: {
                        sum: { field: :provider_price }
                    },
                    total_rspro_reseller_price: {
                        sum: { field: :reseller_price }
                    }
                }
            }
        }
    }
    # If there is no search User filter only current Partners Calls.
    if options[:s_user_id].blank? || %w(-2 -1).include?(options[:s_user_id])
        query[:query][:filtered][:filter][:bool][:must] << { term: { partner_id: options[:current_user][:id] } }
    end
    # Filter the result due to the search
    last_calls_filter(query, options)
  end

  def self.last_calls_totals_user(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            { range: { calldate: { gte: options[:from], lte: options[:till] } } },
                            {
                                bool: {
                                    # Filter only the Calls related to a current User.
                                    should: [
                                        { term: { user_id: options[:current_user][:id] } },
                                        { term:  { dst_user_id: options[:current_user][:id] } },
                                        { terms: { card_id: options[:card_ids] } }
                                    ]
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Total price of Calls made by a current User.
            calls_made_by_user: {
                filter: { term: { user_id: options[:current_user][:id] } },
                aggregations: {
                    total_user_call_price: {
                        sum: { field: :user_price }
                    },
                    total_user_call_did_price: {
                        sum: { field: :did_inc_price }
                    }
                }
            },
            # Total price of Calls answered by a current User.
            calls_answered_by_user: {
                filter: {
                    term: { dst_user_id: options[:current_user][:id] }
                },
                aggregations: {
                    total_user_call_did_price: {
                        sum: { field: :did_price }
                    }
                }
            },
            # Total DID Provider price.
            total_did_prov_price: {
                sum: { field: :did_prov_price }
            },
            # Total DID owner price.
            total_did_price: {
                sum: { field: :did_price }
            },
            # Total duration in seconds.
            total_duration: {
                sum: { script: options[:user_billsec_script] }
            }
        }
    }

    if options[:current_user][:hide_non_answered_calls].to_i == 1
    	query[:query][:filtered][:filter][:bool][:must] << { term: { disposition: 'ANSWERED'} }
    	query[:query][:filtered][:filter][:bool][:must] << { term: { hangupcause: 16} }
    end

    # Filter the result due to the search.
    last_calls_filter(query, options)
  end

  def self.invoice_destinations(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {
                                range: {
                                    calldate: {
                                        gte: options[:from],
                                        lte: options[:till]
                                    }
                                }
                            },
                            {
                                term: {
                                    card_id: 0
                                }
                            },
                            {
                                exists: {
                                    field: 'prefix'
                                }
                            },
                            {
                                bool: {
                                    should: [
                                        {
                                            terms: {
                                                src_device_id: options[:device_ids]
                                            }
                                        },
                                        {
                                            terms: {
                                                dst_device_id: options[:device_ids]
                                            }
                                        }
                                    ]
                                }
                            }
                        ],
                        must_not: [
                            {
                                term: {
                                    prefix: ''
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            grouped_by_dst: {
                terms: {
                    field: 'prefix',
                    size: 0
                },
                aggregations: {
                    grouped_by_user_rate: {
                        terms: {
                            field: 'user_rate',
                            size: 0,
                            order: {
                                _term: 'asc'
                            }
                        },
                        aggregations: {
                            answered_calls: {
                                filter: {
                                    term: {
                                        hangupcause: 16
                                    }
                                },
                                aggregations: {
                                    billsec: {
                                        sum: {
                                            field: options[:billsec_field]
                                        }
                                    },
                                    user_price: {
                                        sum: {
                                            field: :user_price
                                        }
                                    },
                                    did_inc_price: {
                                        sum: {
                                            field: :did_inc_price
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    query[:query][:filtered][:filter][:bool][:must] << {
        bool: {
            should: [
                {
                    range: {
                        user_price: {
                            gt: 0
                        }
                    }
                },
                {
                    range: {
                        did_inc_price: {
                            gt: 0
                        }
                    }
                }
            ]
        }
    } unless options[:show_zero_calls]

    query
  end

  private

  def self.last_calls_filter(query, filters)
    unless filters[:s_user_id].blank? || %w(-2 -1).include?(filters[:s_user_id])
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { term:  { user_id: filters[:s_user_id] } },
                  { term:  { dst_user_id: filters[:s_user_id] } },
                  { terms: { dst_device_id: filters[:device_ids] } },
                  { terms: { card_id: filters[:card_ids] } }
              ]
          }
      }
    end

    if filters[:user_perspective]
        query[:query][:filtered][:filter][:bool][:must] << { term: { user_perspective: 1 } }
    end

    unless filters[:s_device].blank? || filters[:s_device] == 'all'
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { term: { dst_device_id: filters[:s_device].to_i } },
                  { term: { src_device_id: filters[:s_device].to_i } }
              ]
          }
      }
    end

    unless filters[:s_call_type].blank? || filters[:s_call_type] == 'all'
        query[:query][:filtered][:filter][:bool][:must] << { term: { disposition: filters[:s_call_type].to_s.upcase } }
    end

    unless filters[:s_hgc].blank? || filters[:s_hgc].to_i <= 0
        query[:query][:filtered][:filter][:bool][:must] << { term: { hangupcause: filters[:hangup] } } if filters[:hangup]
    end

    unless filters[:s_provider].blank? || filters[:s_provider] == 'all'
        query[:query][:filtered][:filter][:bool][:must] << { term: { provider_id: filters[:s_provider].to_i } }
    end

    unless filters[:s_source].blank?
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { query: { wildcard: { src: filters[:s_source].gsub('%', '*').gsub('_', '?') } } },
                  { query: { wildcard: { clid: filters[:s_source].gsub('%', '*').gsub('_', '?') } } }
              ]
          }
      }
    end

    unless filters[:s_destination].blank?
        query[:query][:filtered][:filter][:bool][:must] << {
          query: { wildcard: { localized_dst: filters[:s_destination].gsub('%', '*').gsub('_', '?') } }
        }
    end

    unless filters[:s_did_pattern].blank? && (filters[:s_reseller_did].blank? || filters[:s_reseller_did] == 'all')
        query[:query][:filtered][:filter][:bool][:must] << { terms: { did_id: filters[:did_ids] } }
    end

    unless filters[:s_reseller].blank? || filters[:s_reseller] == 'all'
        query[:query][:filtered][:filter][:bool][:must] << { term: { reseller_id: filters[:s_reseller].to_i } }
    end

    unless filters[:s_did_provider].blank? || filters[:s_did_provider] == 'all'
        query[:query][:filtered][:filter][:bool][:must] << { term: { did_provider_id: filters[:s_did_provider].to_i } }
    end

    unless filters[:s_card_number].blank? && filters[:s_card_pin].blank? && filters[:s_card_id].blank?
        query[:query][:filtered][:filter][:bool][:must] << { terms: { card_id: filters[:card_ids] } }
    end

    query
  end
end
