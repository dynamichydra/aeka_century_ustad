const config = require("config");

const schemas = config.get("db.pg.schemas");

exports.init = {
  call: async function (dbObj, data) {
    if (data && data.type == "list") {
      
      const { branch_id, prod_id } = data;
      const where = [
        { key: "p##status", operator: "is", value: "active" },
        { key: "b##status", operator: "is", value: "active" },
      ];
      if(prod_id && prod_id != ''){
        where.push({ key: "branch_stock##prod_id", operator: "is", value: prod_id });
      } 
      if(branch_id && branch_id != ''){
        where.push({ key: "branch_stock##branch", operator: "is", value: branch_id });
      }

      let settings = await dbObj.getData("settings", {'where':[
        {'key':'id','operator':'is','value':1}
      ]});
      settings = settings.SUCCESS ? settings.MESSAGE:[];
      const condition = {
        select:
          "branch_stock.id, branch_stock.qnt current_stock, p.sku_no sku_number, p.id prod_id, p.img prod_img, p.code pcode, b.name b_name, b.id branch",
        reference: [
          {
            type: "JOIN",
            obj: "product p",
            a: "p.id",
            b: "branch_stock.prod_id",
          }, {
            type: "JOIN",
            obj: "branch b",
            a: "b.id",
            b: "branch_stock.branch",
          },
        ],
        where: where,
        limit : {
          offset: data?.limit?.offset ?? 0, total: data?.limit?.total ?? 10
        }
      };

      let items = await dbObj.getData("branch_stock", condition);
      let _count = items.COUNT;
      if (items.SUCCESS && items.MESSAGE.length > 0) {
        items = items.MESSAGE;

        let transit = await dbObj.customSQL(`SELECT branch , prod_id , qnt 
            FROM ${schemas}.order_item 
            where (status != 'receive' and status != 'reject') 
              and branch in (${items.map((o) => o.branch).toString()})
              and prod_id in (${items.map((o) => o.prod_id).toString()})
              ;`);

        transit = transit.SUCCESS ? transit.MESSAGE : [];

        let requested = await dbObj.getData("request_item", {
          select:
            "request_item.prod_id prod_id, request_item.qnt qnt, sr.branch branch",
          reference: [
            {
              type: "JOIN",
              obj: "sample_request sr",
              a: "sr.id",
              b: "request_item.sample_request",
            },
          ],
          where: [{
              key: "prod_id",
              operator: "in",
              value:  items.map((o) => o.prod_id).toString() ,
            },{
              key: "branch",
              operator: "in",
              value:  items.map((o) => o.branch).toString() ,
            }],
        });

        requested = requested.SUCCESS ? requested.MESSAGE : [];

        for (let i = 0; i < items.length; i++) {
          let ordered = transit.find((o) => o.prod_id == items[i].prod_id && o.branch == items[i].branch);
          items[i].transit = ordered ? ordered.qnt : 0;

          items[i].max_stock_level = settings.max_stock_level;
          items[i].reorder_qnt = settings.reorder_qnt;

          let req = requested.find((o) => o.prod_id == items[i].prod_id && o.branch == items[i].branch);
          items[i].requested = req ? req.qnt : 0;

        }

        return { SUCCESS: true, MESSAGE: items, COUNT:_count };
      } else {
        return { SUCCESS: false, MESSAGE: "Request not found" };
      }
    } else {
      return { SUCCESS: false, MESSAGE: "Unknown type" };
    }
  },
};
