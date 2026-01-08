const config = require("config");
const cron = require("node-cron");
const sql = require("../modules/pg/common").init;

const schemas = config.get("db.pg.schemas");

//job for checking stock. it will run every day at 1 AM
const stockProd = cron.schedule('0 1 * * *', async () => {
// const stockProd = cron.schedule(
//   "* * * * *",
//   async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }

    const branch = await sql.getData("branch", {
      select: ["id"],
      where: [{ key: "status", operator: "is", value: "active" }],
    });

    if (branch.SUCCESS && branch.MESSAGE.length > 0) {
      for (let i = 0; i < branch.MESSAGE.length; i++) {
        const stock = await sql.customSQL(`SELECT p.id
        FROM ${schemas}.product p
        WHERE NOT EXISTS (
            SELECT 1
            FROM ${schemas}.branch_stock bs
            WHERE bs.prod_id = p.id and bs.branch =${branch.MESSAGE[i].id}
        ) and p.status ='active';`);
        if (stock.SUCCESS && stock.MESSAGE.length > 0) {
          for (let j = 0; j < stock.MESSAGE.length; j++) {
            await sql.setData("branch_stock", {
              branch: branch.MESSAGE[i].id,
              prod_id: stock.MESSAGE[j].id,
              qnt: 0,
            });
          }
        }
      }
    }
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);

//job for checking stock and generating order. it will run every day at 1:30 AM
// const task = cron.schedule('0 9,10,11,12,13,14,15,16,17,18,19,20 * * *', () => {
const task = cron.schedule('30 1 * * *', async () => {
// const task = cron.schedule("5 * * * *",async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }

    const generateOrder = require("./sync/generate_order").init.generateOrder;
    const res = await generateOrder(sql);
    console.log("Generate data completed.");
    console.log(res);
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);

//job for importing creation data (Influencer). it will run every day at 2:00 AM
const creationImportInf = cron.schedule('0 2 * * *', async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }
    const importData = require("./sync/creation").init.importData;
    const res = await importData(sql, 'Influencer');
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);
//job for importing creation data (Retailer). it will run every day at 2:30 AM
const creationImportRet = cron.schedule('30 2 * * *', async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }
    const importData = require("./sync/creation").init.importData;
    const res = await importData(sql, 'Retailer');
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);
//job for importing creation data (Distributor). it will run every day at 3:00 AM
const creationImportDist = cron.schedule('0 3 * * *', async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }
    const importData = require("./sync/creation").init.importData;
    const res = await importData(sql, 'Distributor');
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);
//job for importing creation data (Dealer). it will run every day at 3:30 AM
const creationImportDel = cron.schedule('30 3 * * *', async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }
    const importData = require("./sync/creation").init.importData;
    const res = await importData(sql, 'Dealer');
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);
//job for importing creation data (Scouting). it will run every day at 4:00 AM
const creationImportSoc = cron.schedule('0 4 * * *', async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }
    const importData = require("./sync/creation").init.importData;
    const res = await importData(sql, 'Scouting');
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);
//job for importing creation data (ull). it will run every day at 4:00 AM
const creationImportNull= cron.schedule('30 4 * * *', async () => {
    if (!sql.isConnected()) {
      await sql.connectDB();
    }
    const importData = require("./sync/creation").init.importData;
    const res = await importData(sql);
  },
  {
    scheduled: true,
    timezone: "Asia/Kolkata",
  }
);

stockProd.start();
task.start();
creationImportInf.start();
creationImportRet.start();
creationImportDist.start();
creationImportDel.start();
creationImportSoc.start();
creationImportNull.start();