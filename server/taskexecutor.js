const DokuMe_TaskExecutor = function() {};

DokuMe_TaskExecutor.prototype.executeTask = async function(source, type, task, data){
    const _ = this;
    
    const dbsource = source??'mysql';
    const baseModule = require('./modules/'+dbsource+'/base');
    try {
        const output = await baseModule.lib.init(type, task, data);
        return output;
    } catch (ex) {
        console.log(ex);
        return new Promise( function(resolve,reject) {
            reject({SUCCESS:false, MESSAGE:'Request not found.'});
        });
    }
};

module.exports = DokuMe_TaskExecutor;
