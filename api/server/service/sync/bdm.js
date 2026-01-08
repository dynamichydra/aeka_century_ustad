const fs = require('fs');
const csv = require('csv-parser');
const config = require("config");
const path = require("path");

exports.init = {
  importData: importData,
};

async function importData(sql) {
    console.log("Starting importData function...");
  return new Promise(async function (result) {
      console.log("🔄 Starting product import...");
      const results = [];
      const csvPath = path.join(__dirname, "bdm_sales.csv");
      fs.createReadStream(csvPath)
      .pipe(csv())
      .on("data", (row) => results.push(row))
      .on("end", async () => {
        

        for (const row of results) {
          let bId = await sql.customSQL(
            `SELECT id FROM ${config.get("db.pg.schemas")}.branch WHERE name = $1 LIMIT 1`,
            [row.branch_name]
          );
          if(!bId.SUCCESS || bId.MESSAGE.length == 0){
            bId = await sql.customSQL(
              `INSERT INTO ${config.get("db.pg.schemas")}.branch (code, name, created_by,created_at, status) VALUES ($1,$2,$3,$4,$5) 
                  ON CONFLICT (name)
                  DO UPDATE SET code = $6 RETURNING id; `,
              [row.branch_code,row.branch_name,1,new Date(),"active",row.branch_code]
            );
          }
          bId = bId.MESSAGE[0].id;

          let aUser = await sql.customSQL(
            `SELECT * FROM ${config.get("db.pg.schemas")}.user WHERE type = 'Sales'`
        );

        aUser = aUser.MESSAGE;

        let bAccess = await sql.customSQL(
            `SELECT * FROM ${config.get("db.pg.schemas")}.user_branch_access`
          );
        bAccess = bAccess.MESSAGE;

          let isFound = aUser.find(e=>e.email == row.bdm_email);
          if(!isFound ){
            let sId = await sql.customSQL(
              `INSERT INTO ${config.get("db.pg.schemas")}.user (code, name, email, phone, created_by, created_at, status, type, state, city, zip,tag, pwd) 
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)  RETURNING id; `,
              [row.bdm_code,row.bdm_name, row.bdm_email, row.bdm_ph,1,new Date(),"active",'Sales', 35, 606, 146748, 'BDM', "a39a994cc3e2eb7ec2ca8789d78a6a2278dc365ab2aca6ec1621cd60103eec02"]
            );
            isFound = bAccess.find(e=>e.user_id == sId.MESSAGE[0].id && e.branch_id == bId);
            if(!isFound){
              sId = sId.MESSAGE[0].id;
              const baId = await sql.customSQL(
              `INSERT INTO ${config.get("db.pg.schemas")}.user_branch_access (user_id, branch_id, created_by, created_at) 
                VALUES ($1,$2,$3,$4)  RETURNING id; `,
              [sId,bId,1,new Date()]
            );
            }
          }
          
        }
        result({ SUCCESS: true, MESSAGE: results});
      });
  });


}

