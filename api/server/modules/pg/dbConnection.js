const { Pool } = require('pg');
let config = require('config');
let pgClient;

async function connectToDatabase() {
    if (!pgClient) {
        pgClient = new Pool({
            user: config.get('db.pg.user'),
            host: config.get('db.pg.host'),
            database: config.get('db.pg.db'),
            password: config.get('db.pg.pass'),
            port: config.get('db.pg.port'),
            allowExitOnIdle: true,
            ssl: {
            rejectUnauthorized: false 
            },
            max: 100,           
            idleTimeoutMillis: 30000, 
            connectionTimeoutMillis: 30000,
        });

        await pgClient.connect();
    }

    return pgClient;
}

// global.connectToDatabase =  connectToDatabase;
module.exports = connectToDatabase;