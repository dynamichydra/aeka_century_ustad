const crypto = require('crypto');
const moment = require('moment');

exports.init = {

  call: async function (commonObj, data) {
    console.log(data);

    let _ = this;
    return new Promise(async function (result) {
      if (data) {
        if (data.grant_type == 'branche_revenue') {
          let sql = `SELECT b.name AS branch_name,
                     COALESCE(SUM(c.parcel_cost + c.tax_cost + c.insurance_cost), 0) AS total_revenue,
                     COUNT(c.id) AS total_consignments FROM branche b 
                     LEFT JOIN branche_services_zipcode bs ON bs.branche = b.id
                     LEFT JOIN consignment c ON c.customer_zip = bs.zip `;
          if (data.fdate && data.tdate) {
            const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
            const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
            sql += `AND c.created_at BETWEEN '${fDate}' AND '${tDate}' `;
          }
          if (data.branche_id) {
            sql += ` WHERE b.id = '${data.branche_id}'`
          }
          sql += ` GROUP BY b.id, b.name ORDER BY b.name`;
          let t = await commonObj.customSQL(sql);
          result(t);
        } else if (data.grant_type == 'delivery_mode') {
          let sql = '';
          let cnd = 'WHERE 1'
          sql += `SELECT d.name AS delivery_mode_name,
                 COUNT(c.id) AS consignment_count,
                 COALESCE(SUM(c.parcel_cost), 0) AS total_revenue
                 FROM delivery_mode d
                 LEFT JOIN consignment c
                 ON c.delivery_mode = d.id`
          if (data.fdate && data.tdate) {
            const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
            const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
            sql += ` AND c.created_at BETWEEN '${fDate}' AND '${tDate}' `;
          }
          sql += `GROUP BY d.name
                 ORDER BY consignment_count DESC`

          let t = await commonObj.customSQL(sql);
          result(t);      
        } else if (data.grant_type == 'total_consignment'){
          let sql = " ";
          let cnd = " WHERE 1 ";

          if (data.fdate && data.fdate != '' && data.tdate && data.tdate != '') {
            const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
            const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
            cnd += ` AND (created_at BETWEEN '${fDate}' AND '${tDate}')`;
          }
          sql +=`SELECT status, COUNT(*) AS total_consignment FROM consignment ${cnd} GROUP BY status;`
          let t = await commonObj.customSQL(sql);
          result(t);   
        } else if (data.grant_type == 'delivery_boy_performance'){
          let sql = " ";
          let cnd = " WHERE 1 ";

          if (data.fdate && data.fdate != '' && data.tdate && data.tdate != '') {
            const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
            const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
            cnd += ` AND (ca.date BETWEEN '${fDate}' AND '${tDate}')`;
          }
          sql +=`SELECT db.name AS delivery_boy,
              COUNT(ca.id) AS total_assignments,
              COUNT(CASE WHEN ca.status = 2 THEN 1 END) AS done_count,
              COUNT(CASE WHEN ca.status <> 2 OR ca.status IS NULL THEN 1 END) AS not_done_count
              FROM delivery_boy db
              LEFT JOIN consignment_assignments ca ON ca.delivery_boy_id = db.id
              ${cnd}
              GROUP BY db.id, db.name`
          let t = await commonObj.customSQL(sql);
          result(t); 
        } else if (data.grant_type == 'user_log') {
          let sql = " ";
          let cnd = " WHERE 1 ";

          if (data.uId && data.uId != '') {
            cnd += ` AND U.ph = '${data.uId}' `;
          }

          sql = "SELECT * FROM (";
          sql += "(SELECT name,ph,balance, T.id, 'Transfer' note, amt de, 0 cr, tdate dt FROM `transfer_log` T INNER JOIN `user` U ON U.id = T.fid " + cnd + " )";
          sql += "UNION ";
          sql += "(SELECT name,ph,balance, T.id, 'Receive' note, 0 de, amt cr, tdate dt FROM `transfer_log` T INNER JOIN `user` U ON U.id = T.tid " + cnd + " )";
          sql += " UNION ";
          sql += "(SELECT name,ph,balance, T.id, 'Thailand Lottery' note, amt de, price cr, bdate dt  FROM `thailandLottery` T INNER JOIN `user` U ON U.id = T.user_id " + cnd + " )";
          sql += "UNION  ";
          sql += "(SELECT name,ph,balance, T.id, 'Mumbai Super' note, amt de, price cr, bdate dt  FROM `mumbaiSuper` T INNER JOIN `user` U ON U.id = T.user_id " + cnd + " )";
          sql += "UNION  ";
          sql += "(SELECT name,ph,balance, T.id, 'Motka King' note, amt de, price cr, bdate dt  FROM `motkaKing` T INNER JOIN `user` U ON U.id = T.user_id " + cnd + " )";
          sql += ") AS TBL ";
          sql += "ORDER BY `TBL`.`dt` ASC;"

          let t = await commonObj.customSQL(sql);
          result(t);
        } else if (data.grant_type == 'pl') {
          if (data.pType != 'user') {
            let sql = " ";
            let cnd = " WHERE 1 ";

            if (data.fdate && data.fdate != '' && data.tdate && data.tdate != '') {
              const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
              const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
              cnd += ` AND (R.bdate BETWEEN '${fDate}' AND '${tDate}')`;
            }

            if (data.gName && data.gName != '') {
              cnd += ` AND G.name= '${data.gName}' `;
            }

            if (data.pType == 'admin') {
              sql = "(SELECT SUM(amt) amt,SUM(price) price, U1.ph u1name, U1.id u1id, U1.type u1type ,U2.ph u2name, U2.id u2id, U2.type u2type ,U3.ph u3name, U3.id u3id, U3.type u3type,U4.ph u4name, U4.id u4id, U4.type u4type  FROM `" + data.gCode + "` AS R INNER JOIN game_inplay G ON G.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id LEFT JOIN `user` U2 ON U1.pid = U2.id LEFT JOIN `user` U3 ON U2.pid = U3.id LEFT JOIN `user` U4 ON U3.pid = U4.id " + cnd + " GROUP BY U1.id)";

            } else {
              sql = "(SELECT SUM(amt) amt,SUM(price) price, U1.ph u1name, U1.id u1id, U1.type u1type ,U2.ph u2name, U2.id u2id, U2.type u2type, null u3name, null u3id,null u3type,null , null,null   FROM `" + data.gCode + "` AS R INNER JOIN game_inplay G ON G.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id LEFT JOIN `user` U2 ON U1.pid = U2.id  " + cnd + " AND U2.id =" + data.pId + " GROUP BY U1.id)";
              if (data.pType != 'distributer') {
                sql += " UNION ";
                sql += "(SELECT SUM(amt) amt,SUM(price) price, U1.ph u1name, U1.id u1id, U1.type u1type ,U2.ph u2name, U2.id u2id, U2.type u2type ,U3.ph u3name, U3.id u3id, U3.type u3type,null, null,null  FROM `" + data.gCode + "` AS R INNER JOIN game_inplay G ON G.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id LEFT JOIN `user` U2 ON U1.pid = U2.id LEFT JOIN `user` U3 ON U2.pid = U3.id " + cnd + " AND U3.id =" + data.pId + " GROUP BY U2.id)";

                if (data.pType != 'super') {
                  sql += " UNION ";
                  sql += "(SELECT SUM(amt) amt,SUM(price) price, U1.ph u1name, U1.id u1id, U1.type u1type ,U2.ph u2name, U2.id u2id, U2.type u2type ,U3.ph u3name, U3.id u3id, U3.type u3type,U4.ph u4name, U4.id u4id, U4.type u4type  FROM `" + data.gCode + "` AS R INNER JOIN game_inplay G ON G.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id LEFT JOIN `user` U2 ON U1.pid = U2.id LEFT JOIN `user` U3 ON U2.pid = U3.id LEFT JOIN `user` U4 ON U3.pid = U4.id " + cnd + " AND U4.id =" + data.pId + " GROUP BY U3.id)";

                }
              }
            }

            let t = await commonObj.customSQL(sql);
            result(t);
          } else {
            result({ SUCCESS: false, MESSAGE: 'err' });
          }
        } else if (data.grant_type == 'bet_log_dt') {
          if (data.pType != 'user') {
            let sql = " ";
            let cnd = " WHERE 1 ";

            if (data.uId && data.uId != '') {
              cnd += ` AND user_id = '${data.uId}' `;
            }

            if (data.fdate && data.fdate != '' && data.tdate && data.tdate != '') {
              const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
              const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
              cnd += ` AND (bdate BETWEEN '${fDate}' AND '${tDate}')`;
            }

            if (data.pType == 'admin') {
              sql = "SELECT sum(amt) amt,SUM(price) price, DATE(bdate) dt FROM `" + data.gCode + "` " + cnd + " GROUP BY DATE(bdate) ORDER BY bdate ASC";

            } else {
              sql = "(SELECT sum(amt) amt,SUM(price) price, DATE(bdate) dt FROM `" + data.gCode + "` AS R  INNER JOIN `user` U1 ON U1.id = R.user_id INNER JOIN `user` U2 ON U1.pid = U2.id " + cnd + " AND U2.id =" + data.pId + " GROUP BY DATE(bdate) ORDER BY bdate ASC)";
              if (data.pType != 'distributer') {
                sql += " UNION ";
                sql += "(SELECT sum(amt) amt,SUM(price) price, DATE(bdate) dt FROM `" + data.gCode + "` AS R INNER JOIN `user` U1 ON U1.id = R.user_id INNER JOIN `user` U2 ON U1.pid = U2.id " + cnd + " AND U2.pid =" + data.pId + " GROUP BY DATE(bdate) ORDER BY bdate ASC)";
                if (data.pType != 'super') {
                  sql += " UNION ";
                  sql += "(SELECT sum(amt) amt,SUM(price) price, DATE(bdate) dt FROM `" + data.gCode + "` AS R INNER JOIN `user` U1 ON U1.id = R.user_id INNER JOIN `user` U2 ON U1.pid = U2.id INNER JOIN `user` U3 ON U2.pid = U3.id " + cnd + " AND U3.pid =" + data.pId + " GROUP BY DATE(bdate) ORDER BY bdate ASC)";

                }
              }
            }

            let t = await commonObj.customSQL(sql);
            result(t);
          } else {
            result({ SUCCESS: false, MESSAGE: 'err' });
          }
        } else if (data.grant_type == 'bet_log_name') {
          if (data.pType != 'user') {
            let sql = " ";
            let cnd = " WHERE GM.game_code='" + data.gCode + "' ";

            if (data.uId && data.uId != '') {
              cnd += ` AND r.user_id = '${data.uId}' `;
            }
            if (data.fdate && data.fdate != '' && data.tdate && data.tdate != '') {
              const fDate = moment(data.fdate).format('YYYY-MM-DD') + ' 00:00:00';
              const tDate = moment(data.tdate).format('YYYY-MM-DD') + ' 23:59:59';
              cnd += ` AND (R.bdate BETWEEN '${fDate}' AND '${tDate}')`;
            }

            if (data.pType == 'admin') {
              sql = "SELECT sum(amt) amt,SUM(price) price, GM.name name FROM `" + data.gCode + "` AS R INNER JOIN `game_inplay` AS GM ON GM.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id LEFT JOIN `user` U2 ON U1.pid = U2.id " + cnd + " GROUP BY GM.name ORDER BY GM.name ASC";

            } else {
              sql = "(SELECT sum(amt) amt,SUM(price) price, GM.name name FROM `" + data.gCode + "` AS R INNER JOIN `game_inplay` AS GM ON GM.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id INNER JOIN `user` U2 ON U1.pid = U2.id " + cnd + " AND U2.id =" + data.pId + " GROUP BY GM.name ORDER BY GM.name ASC)";
              if (data.pType != 'distributer') {
                sql += " UNION ";
                sql += "(SELECT sum(amt) amt,SUM(price) price, GM.name name FROM `" + data.gCode + "` AS R INNER JOIN `game_inplay` AS GM ON GM.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id INNER JOIN `user` U2 ON U1.pid = U2.id " + cnd + " AND U2.pid =" + data.pId + " GROUP BY GM.name ORDER BY GM.name ASC)";
                if (data.pType != 'super') {
                  sql += " UNION ";
                  sql += "(SELECT sum(amt) amt,SUM(price) price, GM.name name FROM `" + data.gCode + "` AS R INNER JOIN `game_inplay` AS GM ON GM.id=R.game_id INNER JOIN `user` U1 ON U1.id = R.user_id INNER JOIN `user` U2 ON U1.pid = U2.id INNER JOIN `user` U3 ON U2.pid = U3.id " + cnd + " AND U3.pid =" + data.pId + " GROUP BY GM.name ORDER BY GM.name ASC)";

                }
              }
            }

            let t = await commonObj.customSQL(sql);
            result(t);
          } else {
            result({ SUCCESS: false, MESSAGE: 'err' });
          }
        } else if (data.grant_type == 'user') {
          if (data.pType != 'user') {
            let sql = " ";
            let cnd = " WHERE 1 ";

            if (data.uStatus && data.uStatus != '') {
              cnd += ` AND U1.status = '${data.uStatus}' `;
            }
            if (data.uPh && data.uPh != '') {
              cnd += ` AND U1.email like '%${data.uPh}%' `;
            }
            if (data.uName && data.uName != '') {
              cnd += ` AND U1.name like '%${data.uName}%' `;
            }
            if (data.uId && data.uId != '') {
              cnd += ` AND U1.ph like '%${data.uId}%' `;
            }

            if (data.pType == 'admin') {
              sql = "SELECT U1.id,U1.pid,U1.name,U1.ph,U1.email,U1.type,U1.balance,U1.status,U1.percentage,U2.name pname FROM `user` U1 LEFT JOIN `user` U2 ON U1.pid = U2.id " + cnd;
            } else {
              sql = "(SELECT U1.id,U1.pid,U1.name,U1.ph,U1.email,U1.type,U1.balance,U1.status,U1.percentage,U2.name pname FROM `user` U1 INNER JOIN `user` U2 ON U1.pid = U2.id " + cnd + " AND U2.id =" + data.pId + ")";
              if (data.pType != 'distributer') {
                sql += " UNION ";
                sql += "(SELECT U1.id,U1.pid,U1.name,U1.ph,U1.email,U1.type,U1.balance,U1.status,U1.percentage,U2.name pname FROM `user` U1 INNER JOIN `user` U2 ON U1.pid = U2.id " + cnd + " AND U2.pid =" + data.pId + ")";
                if (data.pType != 'super') {
                  sql += " UNION ";
                  sql += "(SELECT U1.id,U1.pid,U1.name,U1.ph,U1.email,U1.type,U1.balance,U1.status,U1.percentage,U2.name pname FROM `user` U1 INNER JOIN `user` U2 ON U1.pid = U2.id INNER JOIN `user` U3 ON U2.pid = U3.id " + cnd + " AND U3.pid =" + data.pId + ")";
                }
              }
            }

            let t = await commonObj.customSQL(sql);
            result(t);
          } else {
            result({ SUCCESS: false, MESSAGE: 'err' });
          }
        } else if (data.grant_type == 'user_simple') {
          if (data.pType != 'user') {
            let sql = " ";
            let cnd = " WHERE pid= " + data.pId;

            if (data.uStatus && data.uStatus != '') {
              cnd += ` AND status = '${data.uStatus}' `;
            }
            if (data.uPh && data.uPh != '') {
              cnd += ` AND email like '%${data.uPh}%' `;
            }
            if (data.uName && data.uName != '') {
              cnd += ` AND name like '%${data.uName}%' `;
            }
            if (data.uId && data.uId != '') {
              cnd += ` AND ph like '%${data.uId}%' `;
            }

            sql = "SELECT id,pid,name,ph,email,type,balance,status,percentage FROM `user`  " + cnd;

            let t = await commonObj.customSQL(sql);
            result(t);
          } else {
            result({ SUCCESS: false, MESSAGE: 'err' });
          }
        } else {
          result({ SUCCESS: false, MESSAGE: 'err' });
        }
      } else {
        result({ SUCCESS: false, MESSAGE: 'err' });
      }
    });
  },
};