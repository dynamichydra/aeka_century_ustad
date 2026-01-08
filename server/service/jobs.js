// const config = require("config");
// const cron = require("node-cron");
// const sql = require("../modules/pg/common").init;

// const schemas = config.get("db.pg.schemas");

// //job for checking stock. it will run every day at 1 AM
// // const task = cron.schedule('0 1 * * *', async () => {
// const stockProd = cron.schedule(
//   "* * * * *",
//   async () => {
//     if (!sql.isConnected()) {
//       await sql.connectDB();
//     }

//     const branch = await sql.getData("branch", {
//       select: ["id"],
//       where: [{ key: "status", operator: "is", value: "active" }],
//     });

//     if (branch.SUCCESS && branch.MESSAGE.length > 0) {
//       for (let i = 0; i < branch.MESSAGE.length; i++) {
//         const stock = await sql.customSQL(`SELECT p.id
//         FROM ${schemas}.product p
//         WHERE NOT EXISTS (
//             SELECT 1
//             FROM ${schemas}.branch_stock bs
//             WHERE bs.prod_id = p.id and bs.branch =${branch.MESSAGE[i].id}
//         ) and p.status ='active';`);
//         if (stock.SUCCESS && stock.MESSAGE.length > 0) {
//           for (let j = 0; j < stock.MESSAGE.length; j++) {
//             await sql.setData("branch_stock", {
//               branch: branch.MESSAGE[i].id,
//               prod_id: stock.MESSAGE[j].id,
//               qnt: 0,
//             });
//           }
//         }
//       }
//     }
//   },
//   {
//     scheduled: true,
//     timezone: "Asia/Kolkata",
//   }
// );

// //job for checking stock and generating order. it will run every day at 1:30 AM
// // const task = cron.schedule('0 9,10,11,12,13,14,15,16,17,18,19,20 * * *', () => {
// // const task = cron.schedule('30 1 * * *', async () => {
// const task = cron.schedule(
//   "* * * * *",
//   async () => {
//     if (!sql.isConnected()) {
//       await sql.connectDB();
//     }

//     let settings = await sql.getData("settings", {
//       where: [{ key: "id", operator: "is", value: 1 }],
//     });
//     if (settings.SUCCESS) {
//       settings = settings.MESSAGE;

//       let branchRequest =
//         await sql.customSQL(`SELECT sr.branch , ri.prod_id , ri.qnt 
//         FROM ${schemas}.sample_request sr 
//         join ${schemas}.request_item ri on ri.sample_request = sr.id 
//         where sr.status = 'pending';`);
//       branchRequest = branchRequest.SUCCESS ? branchRequest.MESSAGE : [];

//       let branchOrder =
//         await sql.customSQL(`SELECT oi.branch , oi.prod_id , sum(oi.qnt) as qnt
//         FROM ${schemas}.order_item oi
//         where (oi.status != 'receive' and oi.status != 'reject') group by oi.branch,oi.prod_id; `);
//       branchOrder = branchOrder.SUCCESS ? branchOrder.MESSAGE : [];

//       sql
//         .customSQL(
//           `SELECT ${schemas}.branch_stock.* FROM ${schemas}.branch_stock 
//       JOIN ${schemas}.branch ON ${schemas}.branch.id = ${schemas}.branch_stock.branch 
//       WHERE ${schemas}.branch.status='active' AND qnt <= ${settings.reorder_qnt}`
//         )
//         .then(async function (res) {
//           if (res.SUCCESS && res.MESSAGE.length > 0) {
//             for (let i = 0; i < res.MESSAGE.length; i++) {
//               const reqItem = branchRequest.find(function (item) {
//                 return (
//                   item.branch == res.MESSAGE[i].branch &&
//                   item.prod_id == res.MESSAGE[i].prod_id
//                 );
//               });

//               let orderItem = branchOrder.find(function (item) {
//                 return (
//                   item.branch == res.MESSAGE[i].branch &&
//                   item.prod_id == res.MESSAGE[i].prod_id
//                 );
//               });

//               const totalOrder =
//                 settings.max_stock_level -
//                 res.MESSAGE[i].qnt +
//                 (reqItem ? reqItem.qnt : 0) -
//                 (orderItem ? orderItem.qnt : 0);
//               if (totalOrder <= 0) {
//                 continue;
//               }

//               await sql.setData("order_item", {
//                 prod_id: res.MESSAGE[i].prod_id,
//                 qnt: totalOrder,
//                 branch: res.MESSAGE[i].branch,
//                 status: "pending",
//                 remarks: "Auto generated from system",
//               });
//             }
//           }
//         })
//         .catch(function (err) {
//           console.log(err);
//         });
//     }
//   },
//   {
//     scheduled: true,
//     timezone: "Asia/Kolkata",
//   }
// );

// //job for importing creation data. it will run every day at 2:30 AM
// const creationImport = cron.schedule('30 2 * * *', async () => {
// // const creationImport = cron.schedule(
// //   "*/5 * * * *",
// //   async () => {
//     console.log("Starting creation data import job...");
//     if (!sql.isConnected()) {
//       await sql.connectDB();
//     }
//     const importData = require("./sync/creation").init.importData;
//     const res = await importData(sql);
//     console.log("Creation data import completed.");
//     console.log(res);
//   },
//   {
//     scheduled: true,
//     timezone: "Asia/Kolkata",
//   }
// );

// // stockProd.start();
// // task.start();
// // creationImport.start();
