let mysql = require('mysql');
const moment =  require('moment');
require('../../corefunction');
let config = require('config');

let db = null;

let mysqlPool = mysql.createPool({
  host: config.get('db.mysql.host'),
  user: config.get('db.mysql.user'),
  password: config.get('db.mysql.pass'),
  port: config.get('db.mysql.port'),
  connectionLimit: 100,
  acquireTimeout: 50000,
  debug: false,
  timezone: 'Asia/Kolkata',
  database: config.get('db.mysql.dbname')
});



exports.init = {
  tableConfig:config.get('TABLE_DEFINITION'),
  checkColumnExists: function(type, column){
    if(this.tableConfig[type] && this.tableConfig[type].includes(column)){
      return true;
    }else{
      return false;
    }
  },
  connectDB : async function(){
    return new Promise(async function (result) {
      mysqlPool.getConnection(function (err, connection) {
        if (err){
            console.log(err);
            throw err;
        }
        db = connection;
        result(db)
      });
    });
  },
  startTransaction : async function(){
    return new Promise(async function (result) {
      let sql = `START TRANSACTION;`;
      db.query(sql, (err, rows) => {
        if (err) {
          result({SUCCESS:false,MESSAGE:err.message});
        }
        result({SUCCESS:true,MESSAGE:'Ok'});    
      });
    });
  },

  commitTransaction : async function(){
    return new Promise(async function (result) {
      let sql = `COMMIT;`;
      db.query(sql, (err, rows) => {
        if (err) {
          result({SUCCESS:false,MESSAGE:err.message});
        }
        result({SUCCESS:true,MESSAGE:'Ok'});    
      });
    });
  },
  rollbackTransaction : async function(){
    return new Promise(async function (result) {
      let sql = `ROLLBACK;;`;
      db.query(sql, (err, rows) => {
        if (err) {
          result({SUCCESS:false,MESSAGE:err.message});
        }
        result({SUCCESS:true,MESSAGE:'Ok'});    
      });
    });
  },
    getData : async function( type, data){
      let __ = this;
      return new Promise(async function (result) {
        let isId = false;
        let cnd = " WHERE 1 ";
        //console.log(data)
        if(data.where){
            for (const k in data.where) {
              if(!isId && data.where[k].key == 'id')isId=true;
                let key = data.where[k].key.split(".");
                key = key[1]??key[0];
                let tbl = key.split("##");
                key = tbl[1]??tbl[0];
                tbl = tbl[1]?tbl[0]+'.':''
                switch(data.where[k].operator){
                    case "isnot":
                      if(data.where[k] == null || data.where[k] =='null' || data.where[k]=='undefined'){
                        cnd += " AND "+tbl+"`"+key+"` != "+data.where[k].value+" ";
                      }else{
                        cnd += " AND "+tbl+"`"+key+"` != '"+data.where[k].value+"' ";
                      }
                        break;
                    case "higher":
                      cnd += " AND "+tbl+"`"+key+"` > '"+data.where[k].value+"' ";
                        break;
                    case "lower":
                        cnd += " AND "+tbl+"`"+key+"` < '"+data.where[k].value+"' ";
                        break;
                    case "lower-equal":
                      cnd += " AND "+tbl+"`"+key+"` <= '"+data.where[k].value+"' ";
                      break;
                    case "higher-equal":
                      cnd += " AND "+tbl+"`"+key+"` >= '"+data.where[k].value+"' ";
                        break;
                    case "in":
                      cnd += " AND "+tbl+"`"+key+"` IN ("+data.where[k].value+") ";
                        break;
                    case "notin":
                        break;
                    case "isnull":
                        cnd += " AND "+tbl+"`"+key+"` IS NULL ";
                        break;
                    case "like":
                        cnd += " AND "+tbl+"`"+key+"` LIKE '%"+data.where[k].value+"%' ";
                        break;
                    default:
                        cnd += " AND "+tbl+"`"+key+"` = '"+data.where[k].value+"' ";
                        break;
                }
            }
        }
        let select = "*";
        if(data.select){
          select = data.select;
        }
        let limit = ''
        if(data.limit){
          limit = ' LIMIT ' + data.limit.total + ' OFFSET ' + data.limit.offset;
        }
        let order = ' ORDER BY '+type+'.id ';
        if(data.order){
          order = ' ORDER BY '+data.order.by+' '+(data.order.type??'');
        }
        if(data.order1){
          order += ', '+data.order1.by+' '+(data.order1.type??'');
        }
        let join = '';
        if(data.reference){
          for(let item of data.reference){
            // join += ` JOIN ${item.obj} ON ${item.obj}.${item.a}=${item.b}`
            const hasAlias = !!item.on;
            const tableRef = item.obj;
            const alias = hasAlias ? ` ${item.on}` : '';
            const leftSide = `${hasAlias ? item.on : item.obj}.${item.a}`;
            join += ` ${item.type??'JOIN'} ${tableRef}${alias} ON ${leftSide} = ${item.b}`;
          }
        }
        let sql = `SELECT ${select} FROM ${type} ${join} ${cnd} ${order} ${limit}`;
        console.log(sql)
        db.query(sql, (err, rows) => {
            if (err) {
              result({SUCCESS:false,MESSAGE:err.message});
            }
            let curDate = moment().utcOffset("+05:30").format('YYYY-MM-DD HH:mm:ss');
            if (isId) {
              if(rows.length == 0){
                result({SUCCESS:false,MESSAGE:"Object or owner can not be found."});
              }else{
                result({SUCCESS:true,MESSAGE:rows[0],current_time:curDate});
              }
            }else{
              if (data.limit) {
                let retArr = { SUCCESS: true, MESSAGE: rows, current_time: curDate };
                const sql = `SELECT COUNT(*) AS total FROM ${type} ${join} ${cnd}`;
                db.query(sql, (err, rows) => {
                  if (err) {
                    console.log(err);
                    return;
                  }
                  retArr['count'] = rows[0].total;
                  result(retArr);
                });
              }else{
                result({SUCCESS:true,MESSAGE:rows,current_time:curDate});
              }
            }
            // result({SUCCESS:true,MESSAGE:rows});
            
        });
      });
    },
    customSQL : async function(sql){
      let __ = this;

      return new Promise(async function (result) {
        console.log(sql);
        db.query(sql, function(err,rows) {
            if (err) {
              result({SUCCESS:false,MESSAGE:err.message});
            }else{
              result({SUCCESS:true,MESSAGE:rows});
            }
        });
      });
    },
    setData : async function(type, data){
      let __ = this;

      return new Promise(async function (result) {
        let key = [],val = [], sql = null;
        if( data.id){
          for (const k in data) {
            // check if column exists
            if(!__.checkColumnExists(type, k)){
              console.log(`Column ${k} does not exist in ${type}`);
              continue;
            }
            if(k == "id"){
              key.push("`"+k+"`='"+data[k]+"'");
            }else{
              if(data[k] == null || data[k] =='null' || data[k]=='undefined'){
  
                val.push("`"+k+"`=null");
              }else{
                val.push("`"+k+"`='"+data[k]+"'");
              }
            }
          }

          sql = `UPDATE ${type} SET ${val.toString()} WHERE ${key.toString()} `;
        }else{
          for (const k in data) {
            if(!__.checkColumnExists(type, k)){
              console.log(`Column ${k} does not exist in ${type}`);
              continue;
            }
            key.push("`"+k+"`");
            if(data[k] == null || data[k] =='null' || data[k]=='undefined'){
              val.push('null');
            }else{
              val.push("'"+data[k]+"'");
            }
          }
          sql = `INSERT INTO ${type} (${key.toString()}) VALUES( ${val.toString()});`;
        }
        console.log(sql)
        db.query(sql, async function(err) {
          // console.log(this.lastID)
            if (err) {
              result({SUCCESS:false,MESSAGE:err.message});
              console.log(err);
              
            }else if(data.id){
              result({SUCCESS:true,MESSAGE:data.id})
            }else{
              let lastId = await __.customSQL("SELECT LAST_INSERT_ID()  AS id");
              result({SUCCESS:true,MESSAGE:lastId.SUCCESS?lastId.MESSAGE[0].id:0});
            }
            
        });
      });
    },

    setDelete : async function(type, data){
      return new Promise(async function (result) {
        let cnd = " 1 ";
        for (const k in data) {
          cnd += " AND `"+k+"`= '"+data[k]+"' ";
        }
        let sql = `DELETE FROM ${type} WHERE ${cnd}`;
        db.query(sql, function(err) {
            if (err) {
              result({SUCCESS:false,MESSAGE:err.message});

            }else{
              result({SUCCESS:true,MESSAGE:'ok'});
            }
        });
      });
    },

    patchRequest : async function(type, data){
      let __ = this;
      return new Promise(async function (result) {
        let resMsg = [];
        for(let i in data){
          let tmp = {};
          switch (data[i].BACKEND_ACTION){
            case 'delete':
              tmp[data[i].ID_RESPONSE] = await __.setDelete(type,{id:data[i].id});
              resMsg.push(tmp);
              break;
            case 'get':
              tmp[data[i].ID_RESPONSE] = await __.getData(type,{where:[{key: 'id',
                    operator: 'is',
                    value: data[i].id}]});
              resMsg.push(tmp);
            break;
            case 'update':
              tmp[data[i].ID_RESPONSE] = await __.setData(type,data[i]);
              resMsg.push(tmp);
            break;
          }
        }
        result({SUCCESS:true,MESSAGE:resMsg});
      });
    },

    putRequest : async function(type, data){
      let __ = this;
      return new Promise(async function (result) {
        let resMsg = [];
        for(let i in data.data){
          let cndArr = [];
          for(let j in data.dm_keyfield){
            cndArr.push({key:data.dm_keyfield[j], value:data.data[i][data.dm_keyfield[j]], operator:'isequel'});
          }

          let oldData = await __.getData(type,{where:cndArr});
          if(oldData.SUCCESS && oldData.MESSAGE.length>0){
            data.data[i]['id'] = oldData.MESSAGE[0].id;
          }
          
          resMsg.push(await __.setData(type, data.data[i]));
        }
        result({SUCCESS:true,MESSAGE:resMsg});
      });
    },

    current_timestamp: function(){
      return moment().format('YYYY-MM-DD HH:mm:ss');
    }
};