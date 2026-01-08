const { Pool } = require("pg");
let config = require("config");
let pgClient;
let pgPool;

async function connectToDatabase() {
  if (!pgClient) {
    const pgConfig = {
      user: config.get("db.pg.user"),
      host: config.get("db.pg.host"),
      database: config.get("db.pg.db"),
      password: config.get("db.pg.pass"),
      port: config.get("db.pg.port"),
      // allowExitOnIdle: true,
      // max: 100,
      // idleTimeoutMillis: 30000,
      // connectionTimeoutMillis: 30000,
    };
    try {
      if (config.has("db.pg.ssh")) {
        const { createTunnel } = require("tunnel-ssh");
        let tunnel;
        pgConfig['ssl'] = {
            rejectUnauthorized: false, // required for Azure PostgreSQL
        }
        tunnel = await createTunnel(
          {
            autoClose: false, // Set to true if you want the tunnel to close with the process
          },
          {
            port: config.get("db.pg.port"), // Local port for the tunnel
          },
          config.has("db.pg.ssh") ? config.get("db.pg.ssh") : {},
          {
            dstPort: config.get("db.pg.dstPort"), // Remote PostgreSQL port
            dstHost: config.get("db.pg.dstHost"), // IP or hostname of the PostgreSQL server (can be localhost if on the same server as SSH)
          }
        );
      }
    console.log(`SSH tunnel established on local port ${config.get("db.pg.port")}`);

      pgClient = new Pool(pgConfig);

       await pgClient.connect();
    } catch (error) {
      console.error("Error connecting to PostgreSQL via SSH tunnel:", error);
    }
  }
  return pgClient;
}

// global.connectToDatabase =  connectToDatabase;
module.exports = connectToDatabase;
