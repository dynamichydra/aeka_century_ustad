let config = require('config');
const _DatabaseConnector = require('./server/taskexecutor.js');
const _DatabaseWebInterface = require('./server/sync_interface.js');
const _CronJob = require('./server/service/jobs.js');
  // setup webserver
const expressApp = require('./server/express.js')
expressApp.setPort(config.get("PORT"));
expressApp.setIp(config.get("IP"));
expressApp.init();

  //
const dbConnector = new _DatabaseConnector();
const dbWebInterface = new _DatabaseWebInterface(dbConnector, expressApp.app);
dbWebInterface.start();
