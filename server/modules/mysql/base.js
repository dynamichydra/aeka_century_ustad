var commonObj = require('../../modules/mysql/common').init;
exports.lib = {
    init : async function( type, task, data){
        var _ = this;
        if(!data){
          data = {};
        }
        
        switch(task){
            case 'get':
                return new Promise(async function (result) {
                  let dbConnect = await commonObj.connectDB();
                  let res = await commonObj.getData(type, data);
                  dbConnect.release();
                  result(res);
                });
            case 'set':
                return new Promise(async function (result) {
                  let dbConnect = await commonObj.connectDB();
                  let res = await commonObj.setData(type, data);
                  dbConnect.release();
                  result(res);
                });
            case 'delete':
                return new Promise(async function (result) {
                  let dbConnect = await commonObj.connectDB();
                  let res = await commonObj.setDelete(type, data);
                  dbConnect.release();
                  result(res);
                });
            case 'patch':
                return new Promise(async function (result) {
                  let dbConnect = await commonObj.connectDB();
                  let res = await commonObj.patchRequest(type, data);
                  dbConnect.release();
                  result(res);
                });
            case 'put':
                return new Promise(async function (result) {
                  let dbConnect = await commonObj.connectDB();
                  let res = await commonObj.putRequest(type, data);
                  dbConnect.release();
                  result(res);
                });
            default:
                var obj = require('./'+type).init;
                return new Promise(async function (result) {
                  let dbConnect = await commonObj.connectDB();
                  let res = await obj.call(commonObj,data);
                  dbConnect.release();
                  result(res);
                });
        }

        
    },
};