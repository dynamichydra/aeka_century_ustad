const crypto = require('crypto');
const moment =  require('moment');
const path = require('path');
const fs = require('fs');

exports.init = {

  call : async function(commonObj, data){
      let _ = this;
      return new Promise(async function (result) {
        let msg = {SUCCESS:false,MESSAGE:'Not Execute'};
        if(data){
          if(data.grant_type == 'delete_doc'){
            let sql = "DELETE FROM  `"+data.obj+"` WHERE id = "+data.id;
            let t = await commonObj.customSQL(sql);

            if(t.SUCCESS){
              const fileName = data.name;
              const filePath = path.join(__dirname, '../../../uploads', fileName);
              
              if (fs.existsSync(filePath)) {
                fs.unlink(filePath, (err) => {
                  if (err) {
                    msg.MESSAGE = err;
                  }else{
                    msg = {STATUS:true,MESSAGE:'File deleted successfully.'};
                  }
                });
              } else {
                msg.MESSAGE = 'File not found.';
              }
            }
          }else{
            msg.MESSAGE = 'Grand type not found';
          }
        }else{
          msg.MESSAGE = 'Request not found';
        }
        result(msg);
      });
    },
};