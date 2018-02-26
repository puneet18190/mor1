INSERT INTO `calls` 
(`id`, `calldate`                        , `clid`               , `src`       , `dst`       , `channel`, `duration`, `billsec`, `disposition`, `accountcode`, `uniqueid`   , `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)
VALUES
(135 ,DATE_SUB(NOW(), INTERVAL 30 MINUTE),''                    ,'101'        ,'123123'     ,''        ,1800       ,1790      ,'ANSWERED'    ,'2'           ,'1232113371.3',4               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,3         ,0           ,1              ,3            ,0             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(136 ,DATE_SUB(NOW(), INTERVAL 30 MINUTE),''                    ,'101'        ,'123123'     ,''        ,1800       ,1790      ,'ANSWERED'    ,'2'           ,'1232113372.3',2               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,5         ,0           ,1              ,4            ,3             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(137 ,DATE_SUB(NOW(), INTERVAL 25 MINUTE),''                    ,'101'        ,'123123'     ,''        ,1500       ,1490      ,'ANSWERED'    ,'2'           ,'1232113373.3',2               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,5            ,0             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(138 ,DATE_SUB(NOW(), INTERVAL 30 MINUTE),''                    ,'101'        ,'123123'     ,''        ,1800       ,1790      ,'ANSWERED'    ,'2'           ,'1232113370.3',4               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,2            ,0             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(139 ,DATE_SUB(NOW(), INTERVAL 12 MINUTE),''                    ,'101'        ,'123123'     ,''        ,720        ,710       ,'ANSWERED'    ,'2'           ,'1232113371.3',2               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,3         ,0           ,1              ,3            ,0             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(140 ,DATE_SUB(NOW(), INTERVAL 50 SECOND),''                    ,'101'        ,'123123'     ,''        ,250        ,240       ,'ANSWERED'    ,'2'           ,'1232113372.3',4               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,5         ,0           ,1              ,4            ,3             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(141 ,DATE_SUB(NOW(), INTERVAL 30 SECOND),''                    ,'101'        ,'123123'     ,''        ,200        ,190       ,'ANSWERED'    ,'2'           ,'1232113373.3',2               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,5            ,0             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(142 ,DATE_SUB(NOW(), INTERVAL 20 SECOND),''                    ,'101'        ,'123123'     ,''        ,170        ,160       ,'ANSWERED'    ,'2'           ,'1232113370.3',4               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,2            ,0             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(143 ,DATE_SUB(NOW(), INTERVAL 50 SECOND),''                    ,'101'        ,'123123'     ,''        ,150        ,140       ,'ANSWERED'    ,'2'           ,'1232113371.3',6               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,3         ,0           ,1              ,3            ,0             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(144 ,DATE_SUB(NOW(), INTERVAL 50 SECOND),''                    ,'101'        ,'123123'     ,''        ,100        ,90        ,'ANSWERED'    ,'2'           ,'1232113372.3',7               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,5         ,0           ,1              ,4            ,3             ,0               ,0                  ,0                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0),
(145 ,DATE_SUB(NOW(), INTERVAL 50 SECOND),''                    ,'101'        ,'123123'     ,''        ,50         ,40        ,'ANSWERED'    ,'2'           ,'1232113373.3',2               ,7               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,5            ,0             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0);