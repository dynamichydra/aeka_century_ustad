const config = require("config");

exports.init = {
  importData: importData,
};

async function importData(sql, sType) {
    console.log("Starting importData function...");
  return new Promise(async function (result) {
    // try {
      let aUser = await sql.customSQL(
          `SELECT * FROM ${config.get("db.pg.schemas")}.user WHERE type = 'Sales'`
      );
      aUser = aUser.MESSAGE;

      // 2️⃣ Fetch new/updated records from source schema
      let crWrhere = "";
      if(sType && sType.trim() !== ''){
        crWrhere = ` where lead_source_type = '${sType}' `;
      }else{
        crWrhere = ` where lead_source_type IS NULL `;
      }
      const fetchQuery = `
      SELECT *
      FROM analytics_bronze.creation 
      ${crWrhere};
    `;
    console.log("Fetch Query:", fetchQuery);
    //   const fetchQuery = `
    //   SELECT *
    //   FROM analytics_bronze.creation 
    //  where lead_number = '33415352'
    //   ORDER BY TO_TIMESTAMP(last_update_date, 'DD/MM/YYYY') ASC ;
    // `;

    // lead_source_type = 'Influencer'
    //   AND
    // LIMIT 3500
    //  where lead_number = '29299737'

      const creation = await sql.customSQL(fetchQuery);
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
        // try {
          //console.log(lead);
          console.log(`Processing lead: ${lead.lead_number} (${++count}/${newLeads.length})`);

          // await sql.begin();
          // --- Insert or update project ---

          let isFound = aUser.find(e=>e.code == lead.created_by_code);
          if(!isFound ){
            continue;
          }
          const projectRes = await sql.customSQL(
            `INSERT INTO ${config.get("db.pg.schemas")}.project (name, lead_no, lead_qnt, created_by, created_at, status, sales_id)
           VALUES ($1, $2, $3, $4, NOW(), $5, $6)
           ON CONFLICT (lead_no) DO UPDATE SET name = EXCLUDED.name, sales_id=EXCLUDED.sales_id, lead_qnt=EXCLUDED.lead_qnt
           RETURNING id`,
            [
              lead.project_name,
              lead.lead_number,
              lead.tentative_qty || 0,
              1,
              "active",
              isFound.id
            ]
          );
          // console.log(`INSERT INTO ${config.get("db.pg.schemas")}.project (name, lead_no, lead_qnt, created_by, created_at, status, sales_id)
          //  VALUES ($1, $2, $3, $4, NOW(), $5, $6)
          //  ON CONFLICT (lead_no) DO UPDATE SET name = EXCLUDED.name, sales_id=EXCLUDED.sales_id, lead_qnt=EXCLUDED.lead_qnt
          //  RETURNING id`,
          //   [
          //     lead.project_name,
          //     lead.lead_number,
          //     lead.tentative_qty || 0,
          //     1,
          //     "active",
          //     isFound.id
          //   ])
          const projectId = projectRes.MESSAGE[0].id;

          // --- Extract influencer details ---
          const name = lead.next_contact_person_name || lead.lead_source_name || null;
          const code = lead.lead_source_code || null;
          let phone = null;
          const type = lead.lead_source_type || 'Owner';

          if (lead.primary_contact) {
            const match = lead.primary_contact.match(/\b\d{10}\b/);
            if (match) phone = match[0];
          }

          // --- Insert influencer ---
          //console.log('Inserting influencer:', { code, name, phone, projectId, type });
          if(code && code !== 'NA' && code !== 'N/A' && code.trim() !== ''  && name && name !== 'NA' && name !== 'N/A' && name.trim() !== ''){ 
            await sql.customSQL(
              `INSERT INTO ${config.get("db.pg.schemas")}.influencer (code, name, phone, created_by, created_at, status, project_id, type)
            VALUES ($1, $2, $3, 1, NOW(), $4, $5, $6)
            ON CONFLICT (code) DO UPDATE SET project_id = EXCLUDED.project_id, name = EXCLUDED.name, phone=EXCLUDED.phone, type=EXCLUDED.type`,
              [code, name, phone, "active", projectId, type]
            );
            // console.log(`INSERT INTO ${config.get("db.pg.schemas")}.influencer (code, name, phone, created_by, created_at, status, project_id, type)
            // VALUES ($1, $2, $3, 1, NOW(), $4, $5, $6)
            // ON CONFLICT (code) DO UPDATE SET project_id = EXCLUDED.project_id, name = EXCLUDED.name, phone=EXCLUDED.phone, type=EXCLUDED.type`,
            //   [code, name, phone, "active", projectId, type])
            // await sql.commit();
          }
        // } catch (err) {
        //   await sql.rollback();
        //   console.error("❌ Error inserting record:", err.message);
        // }
      }

      result({ SUCCESS: true, MESSAGE: "Import completed successfully." });
    // } catch (err) {
    //   console.error("❌ Import failed:", err.message);
    //   result({ SUCCESS: false, MESSAGE: "Error during import." });
    // }
  });
}