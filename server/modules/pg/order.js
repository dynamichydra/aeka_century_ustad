const config = require("config");

const schemas = config.get("db.pg.schemas");

exports.init = {
  call: async function (dbObj, data) {
    if (data && data.type == "list") {
 
      const { branch_id, prod_id, status, id, uType, from, to, type } = data;

      const condition = {
        select:
          "oi.*,  p.sku_no sku, b.name branch_name",
        reference: [
          {
            type: "JOIN",
            obj: "product p",
            a: "p.id",
            b: "oi.prod_id",
          },{
            type: "JOIN",
            obj: "branch b",
            a: "b.id",
            b: "oi.branch",
          },
        ],
        order:{
          type: "DESC",
          by: "oi.id",
        }
      };

      const where = [];
      if(prod_id && prod_id != ''){
        where.push({ key: "oi##prod_id", operator: "is", value: prod_id });
      } 
      if(branch_id && branch_id != ''){
        where.push({ key: "oi##branch", operator: "is", value: branch_id });
      }
      if(id && id != ''){
        where.push({ key: "oi##id", operator: "is", value: id });
      }
      if(from && from != ''){
        where.push({ key: "oi##created_at", operator: "higher-equal", value: from });
      }
      if(to && to != ''){
        where.push({ key: "oi##created_at", operator: "lower-equal", value: to });
      }

      if(where.length>0){
        condition.where = where;
      }

      let items = await dbObj.getData("order_item oi", condition);
      
      if (items.SUCCESS && items.MESSAGE.length > 0) {
        items = items.MESSAGE;

        let approval = await dbObj.getData("order_approved_log", {
          where: [
            { key: "order_item", operator: "in", value: items.map((o) => o.id).toString() },
          ],
        });
        approval = approval.SUCCESS ? approval.MESSAGE : [];

        let atemArray = [];

        for(let i=0;i<items.length;i++){
          items[i].pmg = approval.filter((o) => o.order_item == items[i].id && o.type=='PMG');
          items[i].commercial = approval.filter((o) => o.order_item == items[i].id && o.type=='Commercial');
          items[i].factory = approval.filter((o) => o.order_item == items[i].id && o.type=='Factory');
          items[i].bat = approval.filter((o) => o.order_item == items[i].id && o.type=='BAT');

          if(uType && uType != '' ){
            if(uType.toLowerCase() == 'pmg' || uType.toLowerCase() == 'bat' || uType.toLowerCase() == 'admin'){
              atemArray.push(items[i]);
            } else if(uType.toLowerCase() == 'commercial' && items[i].pmg.length > 0 && items[i].pmg.find((o) => o.status.toLowerCase() == 'approve')){
              atemArray.push(items[i]);
            } else if(uType.toLowerCase() == 'factory' && items[i].commercial.length > 0){
              atemArray.push(items[i]);
            }
          }
        }
        return { SUCCESS: true, MESSAGE: atemArray };
      } else {
        return { SUCCESS: false, MESSAGE: "Request not found" };
      }
    } else {
      return { SUCCESS: false, MESSAGE: "Unknown type" };
    }
  },
};
