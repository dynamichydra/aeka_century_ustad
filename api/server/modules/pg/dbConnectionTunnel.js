const { createTunnel } = require('tunnel-ssh');
const { Pool } = require('pg');

async function connectToPostgresViaSSHTunnel() {
  const localPort = 5432; // Local port where the tunnel will be established
  const remotePostgresPort = 5433; // Default PostgreSQL port on the remote server

  // SSH Tunnel Configuration
  const sshConfig = {
    host: '20.41.245.93', // IP or hostname of your SSH server (bastion host)
    port: 2226, // SSH port, usually 22
    username: 'devops', // Your username on the SSH server
    password: 'LlmDevOps@2025#', // Your password for the SSH server (or use privateKey)
    // privateKey: require('fs').readFileSync('/path/to/your/private_key.pem'), // Alternative: use SSH key
  };

  // PostgreSQL Configuration (connecting to the local end of the tunnel)
  const pgConfig = {
    user: 'postdbadmin',
    host: 'llmpragyandbpost.postgres.database.azure.com', // Connect to localhost as the tunnel redirects traffic
    database: 'etl-db',
    password: 'CpiL@1984#N@w',
    port: localPort, // Use the local port of the SSH tunnel
    ssl: {
      rejectUnauthorized: false  // required for Azure PostgreSQL
    }
  };

  let tunnel;
  let pool;

  try {
    // Create the SSH tunnel
    tunnel = await createTunnel(
      {
        autoClose: false, // Set to true if you want the tunnel to close with the process
      },
      {
        port: localPort, // Local port for the tunnel
      },
      sshConfig,
      {
        dstPort: remotePostgresPort, // Remote PostgreSQL port
        dstHost: '127.0.0.1', // IP or hostname of the PostgreSQL server (can be localhost if on the same server as SSH)
      }
    );

    console.log(`SSH tunnel established on local port ${localPort}`);

    // Connect to PostgreSQL through the tunnel
    pool = new Pool(pgConfig);
    // Test the connection
    const client = await pool.connect();
    const result = await client.query('SELECT widget, zone, branch, asm_code, asm_name, designation, influencer_sfa_code, influencer_name, influencer_firm_type, lead_number, lead_name, lead_source_type, data_month, "1.00_mm", "0.80_mm", recon, tentative_qty, supplied_quantity FROM analytics_bronze.actionable_summary');
    console.log('PostgreSQL connection successful:', result.rows);
    client.release();

  } catch (error) {
    console.error('Error connecting to PostgreSQL via SSH tunnel:', error);
  } finally {
    // Close the pool and tunnel when done (e.g., when your application shuts down)
    // await pool.end();
    // tunnel.close();
  }
}

connectToPostgresViaSSHTunnel();