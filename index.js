let config = require('config');
const DokuMe_DatabaseConnector = require('./server/taskexecutor.js');
const DokuMe_DatabaseWebInterface = require('./server/sync_interface.js');
const DM_CronJob = require('./server/service/jobs.js');
  // setup webserver
const expressApp = require('./server/express.js')
expressApp.setPort(config.get("PORT"));
expressApp.setIp(config.get("IP"));
expressApp.init();

  //
const dbConnector = new DokuMe_DatabaseConnector();

const dbWebInterface = new DokuMe_DatabaseWebInterface(dbConnector, expressApp.app);
dbWebInterface.start();
