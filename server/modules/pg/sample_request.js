const config = require("config");
const { ref } = require("pdfkit");

const schemas = config.get("db.pg.schemas");

exports.init = {
  call: async function (dbObj, data) {
    if (data && data.type == "detail") {
      const { id } = data;
      if (!id || id == "") {
        return { SUCCESS: false, MESSAGE: "Provide a request id" };
      }

      let sample = await dbObj.getData("sample_request", {
        select: "id, branch",
        where: [{ key: "id", operator: "is", value: id }],
      });
      if (!sample.SUCCESS || sample.MESSAGE.length == 0) {
        return { SUCCESS: false, MESSAGE: "Request not found" };
      }
      sample = sample.MESSAGE;

      let items = await dbObj.getData("request_item", {
        select:
          "request_item.id, request_item.qnt quantity, p.sku_no sku_number, p.id prod_id, request_item.approve_qnt, request_item.receive_qnt",
        reference: [
          {
            type: "JOIN",
            obj: "product p",
            a: "p.id",
            b: "request_item.prod_id",
          },
        ],
        where: [{ key: "sample_request", operator: "is", value: id }],
      });
      if (items.SUCCESS && items.MESSAGE.length > 0) {
        items = items.MESSAGE;

        let cur_stock = await dbObj.getData("branch_stock", {
          select: "prod_id, qnt, id",
          where: [
            { key: "branch", operator: "is", value: sample.branch },
            {
              key: "prod_id",
              operator: "in",
              value: items.map((o) => o.prod_id).toString(),
            },
          ],
        });
        cur_stock = cur_stock.SUCCESS ? cur_stock.MESSAGE : [];

        let transit = await dbObj.customSQL(`SELECT oi.branch , oi.prod_id , oi.qnt 
            FROM ${schemas}.order_item oi
            where oi.branch = ${sample.branch} AND (oi.status != 'received' and oi.status != 'rejection');`);
        transit = transit.SUCCESS ? transit.MESSAGE : [];

        let totalApproved = await dbObj.getData("request_approved_log al", {
          select: "ri.prod_id, al.qnt",
          reference: [
            {
              type: "JOIN",
              obj: "request_item ri",
              a: "ri.id",
              b: "al.request_item",
            },
          ],
          where: [
            { key: "ri##sample_request", operator: "is", value: id },
            {
              key: "al##status",
              operator: "is",
              value: "approved", //change it to approved after testing
            },
          ],
        });
        totalApproved = totalApproved.SUCCESS ? totalApproved.MESSAGE : [];

        for (let i = 0; i < items.length; i++) {
          let ordered = transit.find((o) => o.prod_id == items[i].prod_id);
          items[i].transit = ordered ? ordered.qnt : 0;

          let stock = cur_stock.find((o) => o.prod_id == items[i].prod_id);
          items[i].inStock = stock ? stock.qnt : 0;
          items[i].stock_id = stock ? stock.id : null;

          let approved = totalApproved.filter((o) => o.prod_id == items[i].prod_id);
          items[i].approved = approved.length > 0 ? approved.reduce((a, b) => a + b.qnt, 0) : 0;

          items[i].totalApproved = [totalApproved, items[i].prod_id];

          items[i].receive_qnt = items[i].receive_qnt;
          items[i].approve_qnt = items[i].approve_qnt;
        }

        return { SUCCESS: true, MESSAGE: items };
      } else {
        return { SUCCESS: false, MESSAGE: "Request not found" };
      }
    } else if (data && data.type == "list") {
      const { from, to, lead_no, request_by, status, limit } = data;

      const sql = `
              SELECT
                  sr.id AS request_id,
                  sr.request_at,
                  sr.delivery_type,
                  i.name AS request_for,
                  p.name AS project_name,
                  p.lead_no,
                  p.lead_qnt,
                  u.name AS request_by,
                  CASE
                      WHEN COUNT(DISTINCT ral.id) > 0
                          AND SUM(CASE WHEN ral.status = 'approved' THEN 1 ELSE 0 END) = 0
                          THEN 'Ready_for_Receive'
                      WHEN COUNT(DISTINCT ral.id) > 0
                          AND SUM(CASE WHEN ral.status = 'approved' THEN 1 ELSE 0 END) < COUNT(DISTINCT ri.id)
                          THEN 'Partial'
                      WHEN COUNT(DISTINCT ral.id) > 0
                          AND SUM(CASE WHEN ral.status = 'approved' THEN 1 ELSE 0 END) = COUNT(DISTINCT ri.id)
                          THEN 'Done'
                      ELSE sr.status
                  END AS final_status
              FROM ${schemas}.sample_request sr
              JOIN ${schemas}.user u ON u.id = sr.request_by
              LEFT JOIN ${schemas}.influencer i ON i.id = sr.influencer
              LEFT JOIN ${schemas}.project p ON p.id = sr.project_id
              LEFT JOIN ${schemas}.request_item ri ON ri.sample_request = sr.id
              LEFT JOIN ${schemas}.request_approved_log ral ON ral.request_item = ri.id
              WHERE 1=1
                  AND (
                      COALESCE(array_length($1::int[], 1), 0) = 0 
                      OR sr.request_by = ANY($1)
                  )
                  AND (
                      $2::timestamp IS NULL OR sr.request_at >= $2
                  )
                  AND (
                      $3::timestamp IS NULL OR sr.request_at <= $3
                  )
                  AND (
                      $4::text IS NULL OR sr.status = $4
                  )
                  AND (
                      $5::text IS NULL OR p.lead_no ILIKE $5
                  )
              GROUP BY 
                  sr.id, sr.request_at, sr.delivery_type, i.name, p.name, p.lead_no, p.lead_qnt, u.name, sr.status
              ORDER BY sr.request_at DESC
              `;

              const values = [
                request_by ? [request_by] : [], 
                from || null,                   
                to || null,                     
                status || null,                  
                lead_no || null                  
              ];
      let result = await dbObj.customSQL(sql, values);
      if (result.SUCCESS && result.MESSAGE.length > 0) {
        result = result.MESSAGE;
        return { SUCCESS: true, MESSAGE: result };
      } else {
        return { SUCCESS: false, MESSAGE: "No data found" };
      }
      /**
       * Need more information 
       * 1. need request status base on request_approve_log . 
       *    if Branch approve but sales person not receive then told sales person ready for receive
       *    if one or more item sales person receive show status partial
       *    if all items received then show status is done
       * 
       *  in data.type == "detail" hear need notes fileds.
       */
    } else {
      return { SUCCESS: false, MESSAGE: "Unknown type" };
    }
  },
};
