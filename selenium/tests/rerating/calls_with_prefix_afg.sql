INSERT INTO `calls` (`id`, `calldate`,              `clid`,             `src`           , `dst`  ,     `channel`,  `duration`, `billsec`, `disposition`,  `accountcode`, `uniqueid`  , `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`,`partner_billsec`,`partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)VALUES 
                    (211  ,'2010-09-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''       ,40          ,50    ,'ANSWERED'     ,                       '2' ,'1232113379.3',2,0,0 ,0 ,0    ,1   ,0,0   ,7 ,3   ,3  ,1    ,5  ,3   ,0,0   ,4 ,0  ,0    ,0  ,7,'1231'   ,1 ,16  ,'Outside'  ,3,8 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (224  ,DATE_SUB(NOW(),          INTERVAL 50 SECOND),'456123'        ,'93300017219'  ,'93300017219'     ,'' ,40       ,50    ,'ANSWERED' ,                 '2' ,'1232113379.3',2,0,0 ,0 ,0    ,1   ,0,0   ,4 ,2   ,4  ,1    ,2  ,3   ,0,0   ,4 ,0  ,0    ,0  ,6,'9330'   ,1 ,16  ,'Local',4,9 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (214  ,'2010-12-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                 ,40          ,50    ,'ANSWERED' ,                 '2' ,'1232113379.3',2,0,0 ,0 ,0    ,1   ,0,0   ,8 ,4   ,5  ,1    ,4  ,3   ,0,0   ,4 ,0  ,0    ,0  ,5,'1231'   ,1 ,16  ,'Local',4,7 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (218  ,'2010-07-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                 ,40          ,50    ,'ANSWERED'  ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,1   ,0,0   ,9 ,3   ,3  ,1    ,9  ,3   ,0,0   ,4 ,0  ,0    ,0  ,7,'1231'   ,1 ,16  ,'Outside',3,8 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (229  ,'2010-11-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                 ,40          ,50    ,'ANSWERED'  ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,1   ,0,0   ,15,2   ,4  ,1    ,7  ,3   ,0,0   ,4 ,0  ,0    ,0  ,6,'9330'   ,1 ,16  ,'Local',4,9 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (210  ,'2010-07-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                 ,40          ,50    ,'ANSWERED'  ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,1   ,0,0   ,4 ,4   ,5  ,1    ,11 ,3   ,0,0   ,4 ,0  ,0    ,0  ,5,'1231'   ,1 ,16  ,'Local',4,7 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (215  ,'2010-08-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                  ,40        ,50   , 'ANSWERED'   ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,2   ,0,0   ,2 ,5   ,7  ,1    ,5  ,3   ,0,0   ,8 ,0  ,0    ,0  ,4,'1231'   ,1 ,16  ,'Local',2,9 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (226  ,DATE_SUB(NOW(),          INTERVAL 50 SECOND) ,'456123'       ,'93300017219'  ,'93300017219'      ,'' ,40    ,50   ,  'ANSWERED'   ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,2   ,0,0   ,8 ,6   ,4  ,1    ,2  ,3   ,0,0   ,3 ,0  ,0    ,0  ,7,'1231'   ,1 ,16  ,'Outside',6,3 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (217  ,'2010-12-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                 ,40          ,50     ,'ANSWERED' ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,2   ,0,0   ,12,5   ,9  ,1    ,4  ,3   ,0,0   ,9 ,0  ,0    ,0  ,6,'1231'   ,1 ,16  ,'Outside',5,5 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0),
                    (223  ,'2011-02-18 00:00:01'    ,'456123'           ,'93300017219'  ,'93300017219'  ,''                 ,40          ,50     ,'ANSWERED' ,                '2' ,'1232113379.3',2,0,0 ,0 ,0    ,2   ,0,0   ,6 ,6   ,3  ,1    ,9  ,3   ,0,0   ,2 ,0  ,0    ,0  ,6,'1231'   ,1 ,16  ,'Outside',5,5 ,'123123'   ,0  ,0   ,''    ,''    ,0,0    ,0);  
