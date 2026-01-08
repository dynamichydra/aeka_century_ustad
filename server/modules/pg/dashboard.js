const config = require("config");
const schemas = config.get("db.pg.schemas");

exports.init = {
  call: async function (dbObj, data) {
    if (data && data.type == "order_chart") {
      
      const { branch, uType } = data;

      if(uType == 'Sales'){
        return { SUCCESS: false, MESSAGE: "Unauthorized" };
      }
      const where = (uType == 'BAT' && branch && branch !== '') ? `AND o.branch = ${branch}` : '';
      const sql = `SELECT 
                to_char(months.mon, 'Mon') AS month,
                COALESCE(COUNT(o.id), 0) AS orders
            FROM 
                generate_series(
                    date_trunc('month', CURRENT_DATE - interval '11 months'),
                    date_trunc('month', CURRENT_DATE),
                    interval '1 month'
                ) AS months(mon)
            LEFT JOIN ${schemas}.order_item o 
                ON date_trunc('month', o.created_at) = months.mon
            ${where}
            GROUP BY months.mon
            ORDER BY months.mon;`

      
      let result = await dbObj.customSQL(sql);
      if (result.SUCCESS && result.MESSAGE.length > 0) {
        result = result.MESSAGE;
        return { SUCCESS: true, MESSAGE: result };
      } else {
        return { SUCCESS: false, MESSAGE: "No data found" };
      }
    }else if (data && data.type == "request_table") {
      const { uId, uType, branch } = data;

      let requestBy = [];
      if(uType == 'Sales'){
        requestBy = [uId];
      }else if(uType == 'BAT'){
        const bUser = await dbObj.getData("user", {
          select: "id",
          where: [
            { key: "branch", operator: "is", value: branch }
          ],
        });

        if(bUser && bUser.SUCCESS && bUser.MESSAGE.length >0){
          requestBy = bUser.MESSAGE.map(o => o.id);
        }
      }
      const sql = `SELECT 
            sr.id,
            rb.name AS request_by,
            inf.name AS request_for,
            COUNT(si.id) AS total,
            p.lead_no,
            to_char(sr.request_at, 'YYYY-MM-DD HH24:MI:SS') AS created_at
        FROM ${schemas}.sample_request sr
        LEFT JOIN ${schemas}.user rb ON rb.id = sr.request_by
        LEFT JOIN ${schemas}.influencer inf ON inf.id = sr.influencer
        LEFT JOIN ${schemas}.project p ON p.id = sr.project_id
        LEFT JOIN ${schemas}.request_item si ON si.sample_request = sr.id
        WHERE (COALESCE(array_length($1::int[], 1), 0) = 0 OR sr.request_by = ANY($1))
        GROUP BY sr.id, rb.name, inf.name, p.lead_no, sr.request_at
        ORDER BY sr.request_at DESC
        LIMIT 6;`;

      let result = await dbObj.customSQL(sql,[requestBy]);
      if (result.SUCCESS && result.MESSAGE.length > 0) {
        result = result.MESSAGE;
        return { SUCCESS: true, MESSAGE: result };
      } else {
        return { SUCCESS: false, MESSAGE: "No data found" };
      }
    }else {
      return { SUCCESS: false, MESSAGE: "Unknown type" };
    }
  },
};
