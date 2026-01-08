const fs = require("fs");
const path = require("path");

exports.init = {
    importPincodes: importPincodes,
};

async function importPincodes(sql) {
  console.log("Starting import...");
  return new Promise(async function (result) {
    try {
      console.log("Reading JSON file...");
      const filePath = path.join(
        __dirname,
        "all-india-pincode-json-array.json"
      );

      const rawData = fs.readFileSync(filePath);
      const pincodeData = JSON.parse(rawData);
      console.log(`Total records: ${pincodeData.length}`);
      
      
      const stateCache = new Map();
      const cityCache = new Map();
      const regionCache = new Map();

      for (const item of pincodeData) {
        const { statename, Districtname, pincode, regionname, Deliverystatus } =
          item;
        
        // === Insert State ===
        let stateId = stateCache.get(statename);
        if (!stateId) {
          const stateResult = await sql.customSQL(
            `INSERT INTO inventory.state (name, code, status, created_by, created_at)
           VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id`,
            [statename, statename.substring(0, 3).toUpperCase(), 'active', 1]
          );
          stateId = stateResult.MESSAGE[0].id;
          stateCache.set(statename, stateId);
        }

        // === Insert Region ===
        let regionId = regionCache.get(regionname);
        if (!regionId) {
          const regionResult = await sql.customSQL(
            `INSERT INTO inventory.region (name, status)
           VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id`,
            [regionname, 'active']
          );
          regionId = regionResult.MESSAGE[0].id;
          regionCache.set(regionname, regionId);
        }

        // === Insert City ===
        let cityId = cityCache.get(Districtname);
        if (!cityId) {
          const cityResult = await sql.customSQL(
            `INSERT INTO inventory.city (name, code, state, status, created_by, created_at)
           VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING id`,
            [
              Districtname,
              Districtname.substring(0, 4).toUpperCase(),
              stateId,
              'active',
              1,
            ]
          );
          cityId = cityResult.MESSAGE[0].id;
          cityCache.set(Districtname, cityId);
        }

        // === Insert Zip ===
        await sql.customSQL(
          `INSERT INTO inventory.zip (code, city, status, state, created_by, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW()) ON CONFLICT (code) DO NOTHING`,
          [pincode, cityId, 'active', stateId, 1]
        );
      }

      result("✅ Import completed successfully!");
    } catch (err) {
      result("❌ Error importing data:", err);
    }
  });
}
