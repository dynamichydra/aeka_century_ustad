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
    // try {
      console.log("🔄 Starting product import...");

      const branchResult = await sql.customSQL(`SELECT id, name FROM ${config.get("db.pg.schemas")}.branch`);
      const branchMap = new Map();
      
      // create map with lowercase trimmed name
      branchResult.MESSAGE.forEach(b => {
        branchMap.set(b.name.trim().toLowerCase(), b.id);
      });

      let count = 0;
      const rows = [];
      const filePath = path.join(
              __dirname,
              "product.csv"
            );
      fs.createReadStream(filePath)
        .pipe(csv())
        .on('data', (data) => rows.push(data))
        .on('end', async () => {
          for (const row of rows) {
            const branchName = (row['Branch'] || '').trim().toLowerCase();
            const branchId = branchMap.get(branchName);

            if (!branchId) {
              console.warn(`⚠️ Branch not found for: "${branchName}"`);
              continue;
            }

            const code = (row['SKU Code'] || '').trim();
            const name = (row['Name'] || '').trim();
            const type = (row['Type'] || '').trim();
            const stockQty = parseInt(row['Stock Qty']) || 0;

            // 🧭 Step 3: Insert into product table
            let prodId = null;
            const existingProduct = await sql.customSQL(
                        `SELECT id FROM ${config.get("db.pg.schemas")}.product WHERE sku_no = $1 LIMIT 1`,
                        [code]
                      );
            if (existingProduct.MESSAGE.length > 0) {
              prodId = existingProduct.MESSAGE[0].id;
            }else{
              const productInsert = `
                INSERT INTO ${config.get("db.pg.schemas")}.product (code, name, sku_no, specification, created_by, created_at, status, type)
                VALUES ($1, $2, $3, $4, $5, NOW(), $6, $7)
                RETURNING id
              `;
              const productValues = [code, name, code, type, '1', 'active', type];
              const productRes = await sql.customSQL(productInsert, productValues);
              prodId = productRes.MESSAGE[0].id;
            }
            if (!prodId) {
              console.warn(`⚠️ Failed to get or create product for code: "${code}"`);
              continue;
            }

            // 🧭 Step 4: Insert into branch_stock
            const existingStock = await sql.customSQL(
                        `SELECT id FROM ${config.get("db.pg.schemas")}.branch_stock WHERE branch = $1 AND prod_id = $2 LIMIT 1`,
                        [branchId, prodId]
                      );
            if (existingStock.MESSAGE.length > 0) {
              // Update existing stock
              const stockId = existingStock.MESSAGE[0].id;
              const stockUpdate = `
                UPDATE ${config.get("db.pg.schemas")}.branch_stock
                SET qnt = $1
                WHERE id = $2
              `;
              await sql.customSQL(stockUpdate, [stockQty, stockId]);
            }else{
              const stockInsert = `
                INSERT INTO ${config.get("db.pg.schemas")}.branch_stock (branch, prod_id, qnt)
                VALUES ($1, $2, $3)
              `;
              await sql.customSQL(stockInsert, [branchId, prodId, stockQty]);
            }

            console.log(`✅ Imported: ${count++}/${rows.length} ${name} (${code}) for branch ${branchName}`);
          }

          console.log('🎉 Import completed successfully!');
          result({ SUCCESS: true, MESSAGE: "Import completed successfully." });
        });
    // } catch (err) {
    //   console.error("❌ Import failed:", err.message);
    //   result({ SUCCESS: false, MESSAGE: "Error during import." });
    // }
  });
}