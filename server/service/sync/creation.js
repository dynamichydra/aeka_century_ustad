const config = require("config");

exports.init = {
  importData: importData,
};

async function importData(sql) {
    console.log("Starting importData function...");
  return new Promise(async function (result) {
    try {
      console.log("🔄 Starting daily import...");

      // 1️⃣ Get last update time from settings table
      const settingsRes = await sql.customSQL(
        `SELECT creation_last_update FROM ${config.get("db.pg.schemas")}.settings LIMIT 1`
      );
      const lastUpdate = settingsRes.MESSAGE[0]?.creation_last_update || "1970-01-01";
      console.log(`📅 Last update was: ${lastUpdate}`);

      // 2️⃣ Fetch new/updated records from source schema
      const fetchQuery = `
      SELECT *
      FROM analytics_bronze.creation
      WHERE  TO_TIMESTAMP(last_update_date, 'DD/MM/YYYY') > $1
      ORDER BY TO_TIMESTAMP(last_update_date, 'DD/MM/YYYY') ASC ;
    `;

    // lead_source_type = 'Influencer'
    //   AND
    // LIMIT 3500

      const creation = await sql.customSQL(fetchQuery, [lastUpdate]);
      const newLeads = creation.MESSAGE;

      if (newLeads.length === 0) {
        console.log("✅ No new influencer leads found.");
        result({ SUCCESS: true, MESSAGE: "No new records to import." });
        return;
      }

      console.log(`🆕 Found ${newLeads.length} new influencer records.`);
      let count = 0;
      // 3️⃣ Process each record
      for (const lead of newLeads) {
        try {
          
          console.log(`Processing lead: ${lead.lead_number} (${++count}/${newLeads.length})`);

          const existingLead = await sql.customSQL(
            `SELECT id FROM ${config.get("db.pg.schemas")}.project WHERE lead_no = $1 LIMIT 1`,
            [lead.lead_number]
          );
          if (existingLead.MESSAGE.length > 0) {
            continue;
          }
          await sql.begin();
          // --- Insert or update project ---
          const projectRes = await sql.customSQL(
            `INSERT INTO ${config.get("db.pg.schemas")}.project (name, lead_no, lead_qnt, created_by, created_at, status)
           VALUES ($1, $2, $3, $4, NOW(), $5)
           ON CONFLICT (lead_no) DO UPDATE SET name = EXCLUDED.name
           RETURNING id`,
            [
              lead.project_name,
              lead.lead_number,
              lead.tentative_qty || 0,
              1,
              "active",
            ]
          );
          const projectId = projectRes.MESSAGE[0].id;

          // --- Insert or update branch ---
          const branchRes = await sql.customSQL(
            `INSERT INTO ${config.get("db.pg.schemas")}.branch (name, code, status, created_by, created_at)
           VALUES ($1, $2, $3, $4, NOW())
           ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
           RETURNING id`,
            [
              lead.branch,
              lead.branch?.substring(0, 5).toUpperCase(),
              "active",
              1,
            ]
          );
          const branchId = branchRes.MESSAGE[0].id;

          // --- Extract influencer details ---
          const name = lead.next_contact_person_name || lead.lead_source_name || null;
          const code = lead.lead_source_code || null;
          let phone = null;

          if (lead.primary_contact) {
            const match = lead.primary_contact.match(/\b\d{10}\b/);
            if (match) phone = match[0];
          }

          // --- Insert influencer ---
          if(code && code !== 'NA' && code !== 'N/A' && code.trim() !== ''  && name && name !== 'NA' && name !== 'N/A' && name.trim() !== ''){ 
            await sql.customSQL(
              `INSERT INTO ${config.get("db.pg.schemas")}.influencer (code, name, phone, created_by, created_at, status, project_id)
            VALUES ($1, $2, $3, $4, NOW(), $5, $6)
            ON CONFLICT (code) DO NOTHING`,
              [code, name, phone, 1, "active", projectId]
            );
            await sql.commit();
          }
        } catch (err) {
          await sql.rollback();
          console.error("❌ Error inserting record:", err.message);
        }
      }

      // 4️⃣ Update last update time in settings
      const latestDate = newLeads[newLeads.length - 1].last_update_date;
      await sql.customSQL(
        `UPDATE ${config.get("db.pg.schemas")}.settings SET creation_last_update = TO_TIMESTAMP($1, 'DD/MM/YYYY')`,
        [latestDate]
      );

      console.log(`✅ Import complete. Updated last_update → ${latestDate}`);
      result({ SUCCESS: true, MESSAGE: "Import completed successfully." });
    } catch (err) {
      console.error("❌ Import failed:", err.message);
      result({ SUCCESS: false, MESSAGE: "Error during import." });
    }
  });
}