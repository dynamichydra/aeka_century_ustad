const config = require("config");

const schemas = config.get("db.pg.schemas");

exports.init = {
  generateOrder: generateOrder,
};

async function generateOrder(sql) {
  console.log("Starting importData function...");
  return new Promise(async function (result) {
    // try {
    console.log("🔄 Starting Generating data...");

    let settings = await sql.getData("settings", {
      where: [{ key: "id", operator: "is", value: 1 }],
    });
    if (settings.SUCCESS) {
      settings = settings.MESSAGE;

      let branchRequest =
        await sql.customSQL(`SELECT sr.branch , ri.prod_id , ri.qnt 
        FROM ${schemas}.sample_request sr 
        join ${schemas}.request_item ri on ri.sample_request = sr.id 
        where sr.status = 'pending';`);
      branchRequest = branchRequest.SUCCESS ? branchRequest.MESSAGE : [];

      let branchOrder =
        await sql.customSQL(`SELECT oi.branch , oi.prod_id , sum(oi.qnt) as qnt
        FROM ${schemas}.order_item oi
        where (oi.status != 'receive' and oi.status != 'reject') group by oi.branch,oi.prod_id; `);
      branchOrder = branchOrder.SUCCESS ? branchOrder.MESSAGE : [];

      sql
        .customSQL(
          `SELECT ${schemas}.branch_stock.* FROM ${schemas}.branch_stock 
      JOIN ${schemas}.branch ON ${schemas}.branch.id = ${schemas}.branch_stock.branch 
      WHERE ${schemas}.branch.status='active' AND qnt <= ${settings.reorder_qnt}`
        )
        .then(async function (res) {
          if (res.SUCCESS && res.MESSAGE.length > 0) {
            for (let i = 0; i < res.MESSAGE.length; i++) {
              const reqItem = branchRequest.find(function (item) {
                return (
                  item.branch == res.MESSAGE[i].branch &&
                  item.prod_id == res.MESSAGE[i].prod_id
                );
              });

              let orderItem = branchOrder.find(function (item) {
                return (
                  item.branch == res.MESSAGE[i].branch &&
                  item.prod_id == res.MESSAGE[i].prod_id
                );
              });

              const totalOrder =
                settings.max_stock_level -
                res.MESSAGE[i].qnt +
                (reqItem ? reqItem.qnt : 0) -
                (orderItem ? orderItem.qnt : 0);
              if (totalOrder <= 0) {
                continue;
              }

              await sql.setData("order_item", {
                prod_id: res.MESSAGE[i].prod_id,
                qnt: totalOrder,
                branch: res.MESSAGE[i].branch,
                status: "pending",
                remarks: "Auto generated from system",
              });
            }
          }
          result({ SUCCESS: true, MESSAGE: "Done" });
        })
        .catch(function (err) {
          console.log(err);
          result({ SUCCESS: false, MESSAGE: err });
        });
    }
    // } catch (err) {
    //   console.error("❌ Import failed:", err.message);
    //   result({ SUCCESS: false, MESSAGE: "Error during import." });
    // }
  });
}
