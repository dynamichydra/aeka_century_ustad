const config = require("config");

const schemas = config.get("db.pg.schemas");

exports.init = {
  call: async function (dbObj, data) {
    if (data && data.type == "list") {
 
      const { branch_id, prod_id, status, id, uType, from, to, type, limitTotal, limitOffset } = data;

      let sqlWhere = '1=1';
      if(prod_id && prod_id != ''){
        sqlWhere += ` AND oi.prod_id = ${prod_id} `;
      } 
      if(branch_id && branch_id != ''){
        sqlWhere += ` AND oi.branch = ${branch_id} `;
      }
      if(id && id != ''){
        sqlWhere += ` AND oi.id = ${id} `;
      }
      if(from && from != ''){
        sqlWhere += ` AND oi.created_at >= '${from}' `;
      }
      if(to && to != ''){
        sqlWhere += ` AND oi.created_at <= '${to}' `;
      }

      if(status && status != '' ){
        switch(status.toLowerCase()){
          case 'pmg_pending':
            sqlWhere += ` AND oi.pmg_status = 'pending'  `;
          break;
          case 'pmg_approve':
            sqlWhere += ` AND oi.pmg_status = 'approve'  `;
          break;
          case 'pmg_reject':
            sqlWhere += ` AND oi.pmg_status = 'reject'  `;
          break;
          case 'commercial_pending':
            sqlWhere += ` AND oi.commercial_status = 'pending' `;
          break;
          case 'commercial_approve':
            sqlWhere += ` AND oi.commercial_status = 'approve'  `;
          break;
          case 'factory_pending':
            sqlWhere += ` AND oi.factory_status = 'pending'  `;
          break;
          case 'factory_manufacturing':
            sqlWhere += ` AND oi.factory_status = 'manufacturing'  `;
          break;
          case 'factory_delivery':
            sqlWhere += ` AND oi.factory_status = 'delivery'  `;
          break;
          case 'bat_pending':
            sqlWhere += ` AND oi.bat_status = 'pending'  `;
          break;
          case 'bat_receive':
            sqlWhere += ` AND oi.bat_status = 'receive'  `;
          break;
        }
      }
      
      if(uType && uType != '' ){
        if(uType.toLowerCase() == 'factory'){
          sqlWhere += ` AND oi.commercial_status = 'approve' `;
        }else if(uType.toLowerCase() == 'commercial'){
          sqlWhere += ` AND oi.pmg_status = 'approve' `;
        }
      }

      let sql = `SELECT count(oi.id) as total_count
                FROM ${schemas}.order_item oi
                JOIN ${schemas}.product p ON p.id = oi.prod_id
                JOIN ${schemas}.branch b ON b.id = oi.branch
                WHERE ${sqlWhere}`;
      let itemsTot = await dbObj.customSQL(sql);

      sql = `SELECT oi.*,
                    p.sku_no AS sku,
                    p.name AS pname,
                    p.code AS pcode,
                    b.name AS branch_name
                FROM ${schemas}.order_item oi
                JOIN ${schemas}.product p ON p.id = oi.prod_id
                JOIN ${schemas}.branch b ON b.id = oi.branch
                WHERE ${sqlWhere}
                ORDER BY oi.id DESC
                LIMIT ${limitTotal || 10} OFFSET ${limitOffset || 0};`;
      let items = await dbObj.customSQL(sql);

      console.log(sql);
      
      if (items.SUCCESS && items.MESSAGE.length > 0) {
        return { SUCCESS: true, MESSAGE: items.MESSAGE, COUNT : itemsTot.SUCCESS ? itemsTot.MESSAGE[0].total_count : 0 };
      } else {
        return { SUCCESS: false, MESSAGE: "Data not found" };
      }
    } else {
      return { SUCCESS: false, MESSAGE: "Unknown type" };
    }
  },
};
