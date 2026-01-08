const commonObj = require('../../modules/pg/common').init;


exports.lib = {
    init : async function( rb){
      if(!rb.TASK){
        return {SUCCESS:false, MESSAGE:'Invalid request'};
      }

      const dbConnect = await commonObj.connectDB();
      
      if(rb.TASK == 'location_import'){
        return new Promise(async function (result) {
          const importPincodes = require('./location').init.importPincodes;
          const res = await importPincodes(commonObj);
          console.log('Location data import completed.');
          result(res);
        });
      }else if(rb.TASK == 'creation_import'){
        return new Promise(async function (result) {
          const importData = require('./creation').init.importData;
          const res = await importData(commonObj);
          console.log('Creation data import completed.');
          result(res);
        });
      }else if(rb.TASK == 'product_import'){
        return new Promise(async function (result) {
          const importData = require('./product').init.importData;
          const res = await importData(commonObj);
          console.log('Product data import completed.');
          result(res);
        });
      }
    }
};