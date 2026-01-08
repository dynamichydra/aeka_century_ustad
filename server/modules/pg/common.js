// const { Pool } = require("pg");
const moment = require("moment");
require("../../corefunction");
let config = require("config");
const connectToDatabase = require("../../modules/pg/dbConnection");
let pgPool = null;

// require("../../modules/pg/dbConnectionTunnel");
exports.init = {
  tableConfig: config.get("TABLE_DEFINITION"),

  connectDB: async function () {
    return new Promise(async function (result) {
      pgPool = await connectToDatabase();
      result(pgPool);
    });
  },

  isConnected: function () {
    if (pgPool) return true;
    else return false;
  },

  checkColumnExists: function (type, column) {
    if (this.tableConfig[type] && this.tableConfig[type].includes(column)) {
      return true;
    } else {
      return false;
    }
  },
  getData: async function (type, data) {
    let __ = this;
    return new Promise(async function (result) {
      // result({SUCCESS:false,MESSAGE:"Object or owner can not be found."});return;
      let isId = false;
      let cnd = "";
      //console.log(data)
      if (data.where) {
        let count = "f";
        for (const k in data.where) {
          if (!isId && data.where[k].key == "id") isId = true;
          let key = data.where[k].key.split(".");
          key = key[1] ?? key[0];
          let tbl = key.split("##");
          key = tbl[1] ?? tbl[0];
          tbl = tbl[1] ? tbl[0] + "." : "";
          console.log(tbl)
          if (count == "f") count = " ";
          else count = " AND ";

          key = key == "customid" ? "id" : key;
          switch (data.where[k].operator) {
            case "isnot":
              if (
                data.where[k] == null ||
                data.where[k] == "null" ||
                data.where[k] == "undefined"
              ) {
                cnd += count +tbl+ key + " != " + data.where[k].value + " ";
              } else {
                cnd += count +tbl+ key + " != '" + data.where[k].value + "' ";
              }
              break;
            case "higher":
              cnd += count +tbl+ key + " > '" + data.where[k].value + "' ";
              break;
            case "lower":
              cnd += count +tbl+ key + " < '" + data.where[k].value + "' ";
              break;
            case "lower-equal":
              cnd += count +tbl+ key + " <= '" + data.where[k].value + "' ";
              break;
            case "higher-equal":
              cnd += count +tbl+ key + " >= '" + data.where[k].value + "' ";
              break;
            case "in":
              cnd += count +tbl+ key + " IN (" + data.where[k].value + ") ";
              break;
            case "notin":
              break;
            case "isnull":
              cnd += count +tbl+ key + " IS NULL ";
              break;
            case "like":
              cnd += count +tbl+ key + " ILIKE '%" + data.where[k].value + "%' ";
              break;
            default:
              cnd += count +tbl+ key + " = '" + data.where[k].value + "' ";
              break;
          }
        }
        cnd = " WHERE " + cnd;
      }
      let select = "*";
      if (data.select) {
        select = data.select;
      }
      let limit = "";
      if (data.limit) {
        limit = ' LIMIT ' + data.limit.total + ' OFFSET ' + data.limit.offset;
      }
      // let order = ` ORDER BY ${type}.id `;
      let order = ` `;
      if (data.order) {
        order = " ORDER BY " + data.order.by + " " + (data.order.type ?? "");
      }
      if (data.order1) {
        order += ", " + data.order1.by + " " + (data.order1.type ?? "");
      }
      let join = "";
      if (data.reference) {
        for (let item of data.reference) {
          join += ` ${item.type ?? "JOIN"} ${config.get("db.pg.schemas")}.${
            item.obj
          } ON ${item.a}=${item.b}`;
        }
      }
      let sql = `SELECT ${select} FROM ${config.get(
        "db.pg.schemas"
      )}.${type} ${join} ${cnd} ${order} ${limit}`;
      console.log(sql);
      let pgData = await pgPool.query(sql);

      if (isId) {
        if (pgData.rows.length == 0) {
          result({
            SUCCESS: false,
            MESSAGE: "Object or owner can not be found.",
          });
        } else {
          result({ SUCCESS: true, MESSAGE: pgData.rows[0] });
        }
      } else {
        let retArr = { SUCCESS: true, MESSAGE: pgData.rows };
        if (data.limit) {
          sql = `SELECT count(*) FROM ${config.get('db.pg.schemas')}.${type} ${join} ${cnd}`;
          const totData = await pgPool.query(sql);
          retArr['COUNT'] = totData.rows[0].count;
        }
        result(retArr);
      }
    });
  },
  customSQL: async function (sql, params = []) {
    let __ = this;

    return new Promise(async function (result) {
      let pgData = await pgPool.query(sql, params);
      result({ SUCCESS: true, MESSAGE: pgData.rows});
    });
  },
  setData: async function (type, data) {
    let __ = this;

    return new Promise(async function (result) {
      let key = [],
        val = [],
        sql = null;

      if(data.ckUnique){
        let cnd = "";
        for (const obj of data.ckUnique) {
          const key = Object.keys(obj)[0];
          const value = obj[key]; 
          if (cnd != "") cnd += " OR ";
          else cnd = " ( ";
          cnd += key + "='" + value + "'";
        }
        cnd += ")";
        if(data.id) cnd += " AND id!='"+data.id+"' ";

        let sqlCk = `SELECT id FROM ${config.get("db.pg.schemas")}.${type} WHERE ${cnd} LIMIT 1`;
        console.log(sqlCk);
        let pgDataCk = await pgPool.query(sqlCk);
        console.log(pgDataCk)
        if(pgDataCk.rows.length>0){
          result({ SUCCESS: false, MESSAGE: "Duplicate entry found!" });
          return;
        }
        delete data.ckUnique;
      }

      if (data.id) {
        for (const k in data) {
          // check if column exists
          if (!__.checkColumnExists(type, k)) {
            console.log(`Column ${k} does not exist in ${type}`);
            continue;
          }
          if (k == "id") {
            key.push(k + "='" + data[k] + "'");
          } else {
            if (
              data[k] == null ||
              data[k] == "null" ||
              data[k] == "undefined"
            ) {
              val.push(k + "=null");
            } else {
              if (k == "customid") val.push("id='" + data[k] + "'");
              else val.push(k + "='" + data[k] + "'");
            }
          }
        }

        sql = `UPDATE ${config.get(
          "db.pg.schemas"
        )}.${type} SET ${val.toString()} WHERE ${key.toString()} `;
      } else {
        for (const k in data) {
          if (!__.checkColumnExists(type, k)) {
            console.log(`Column ${k} does not exist in ${type}`);
            continue;
          }
          if (k == "customid") key.push("id");
          else key.push(k);
          if (data[k] == null || data[k] == "null" || data[k] == "undefined") {
            val.push("null");
          } else {
            val.push("'" + data[k] + "'");
          }
        }
        sql = `INSERT INTO ${config.get(
          "db.pg.schemas"
        )}.${type} (${key.toString()}) VALUES( ${val.toString()}) RETURNING id;`;
      }
      console.log(sql);
      let pgData = await pgPool.query(sql);
      result({ SUCCESS: true, MESSAGE: pgData.rows });
    });
  },

  setDelete: async function (type, data) {
    return new Promise(async function (result) {
      try {
        let cnd = "";
        for (const k in data) {
          cnd += (cnd != "" ? " AND " : "") + k + " = '" + data[k] + "' ";
        }
        let sql = `DELETE FROM ${config.get(
          "db.pg.schemas"
        )}.${type} WHERE ${cnd}`;
        // console.log(sql)
        let pgData = await pgPool.query(sql);
        result({ SUCCESS: true, MESSAGE: pgData });
      } catch (e) {
        console.log(e);
        if (e.code == 23503) {
          result({
            SUCCESS: false,
            MESSAGE:
              "Unable to delete. There are some referance data available.",
          });
        } else {
          result({ SUCCESS: false, MESSAGE: "Not able to delete!!" });
        }
      }
    });
  },

  patchRequest: async function (type, data) {
    let __ = this;
    return new Promise(async function (result) {
      let resMsg = [];
      for (let i in data) {
        let tmp = {};
        switch (data[i].BACKEND_ACTION) {
          case "delete":
            tmp[data[i].ID_RESPONSE] = await __.setDelete(type, {
              id: data[i].id,
            });
            resMsg.push(tmp);
            break;
          case "get":
            tmp[data[i].ID_RESPONSE] = await __.getData(type, {
              where: [{ key: "id", operator: "is", value: data[i].id }],
            });
            resMsg.push(tmp);
            break;
          case "update":
            tmp[data[i].ID_RESPONSE] = await __.setData(type, data[i]);
            resMsg.push(tmp);
            break;
        }
      }
      result({ SUCCESS: true, MESSAGE: resMsg });
    });
  },

  putRequest: async function (type, data) {
    let __ = this;
    return new Promise(async function (result) {
      let resMsg = [];
      for (let i in data.data) {
        let cndArr = [];
        for (let j in data.dm_keyfield) {
          cndArr.push({
            key: data.dm_keyfield[j],
            value: data.data[i][data.dm_keyfield[j]],
            operator: "isequel",
          });
        }

        let oldData = await __.getData(type, { where: cndArr });
        if (oldData.SUCCESS && oldData.MESSAGE.length > 0) {
          data.data[i]["id"] = oldData.MESSAGE[0].id;
        }

        resMsg.push(await __.setData(type, data.data[i]));
      }
      result({ SUCCESS: true, MESSAGE: resMsg });
    });
  },

  current_timestamp: function () {
    return moment().format("YYYY-MM-DD HH:mm:ss");
  },

  begin: function () {
    return new Promise(async function (result) {
      const pgData = await pgPool.query("BEGIN");
      result({ SUCCESS: true, MESSAGE: pgData });
    });
  },

  commit: function () {
    return new Promise(async function (result) {
      const pgData = await pgPool.query("COMMIT");
      result({ SUCCESS: true, MESSAGE: pgData });
    });
  },
  
  rollback: function () {
    return new Promise(async function (result) {
      const pgData = await pgPool.query("ROLLBACK");
      result({ SUCCESS: true, MESSAGE: pgData });
    });
  },

};
