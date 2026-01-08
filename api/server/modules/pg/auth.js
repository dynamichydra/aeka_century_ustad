const impFunction = require("../../lib/impFunction");
const notification = require("../../modules/mysql/notification").init;

const jwt = require("jsonwebtoken");
let config = require("config");
const moment = require("moment");
const axios = require("axios");
const crypto = require('crypto');
exports.init = {
  // Your secret key for signing tokens
  secretKey: "Sharow72$0q!3lddYrnb>u0",
  tokenBlacklist: new Set(),

  call: async function (commonObj, data) {
    let _ = this;
    return new Promise(async function (result) {
      if (data) {
        //type login
        if (data.grant_type == "password") {
          if (data.username && data.password) {
            // const verificationURL = `https://www.google.com/recaptcha/api/siteverify?secret=6LcXV3oqAAAAAEvwmA4556g_HZlqGpdMUmShEjLt&response=${data.token}`;
            // const response = await axios.post(verificationURL);
            // const verificationResult = response.data;
            // if (verificationResult.success && verificationResult.score > 0.5) {

            let userCk = await commonObj.customSQL(
              `SELECT id, status FROM ${config.get('db.pg.schemas')}.user 
              WHERE email='${data.username}' OR phone='${data.username}' ${data.tag? `and type = '3'`:``}`
            );
            if (userCk.SUCCESS && userCk.MESSAGE.length > 0) {
              if (userCk.MESSAGE[0].status == 'active') {
                const accessToken = _.encryptStr(
                  _.createAccessToken({
                    type: config.get('USER_TYPE')[userCk.MESSAGE[0].type-2] || 'user',
                    userId: data.username,
                    id: userCk.MESSAGE[0].id,
                  })
                );
                let wr = [
                  { key: "pwd", operator: "is", value: data.password },
                  { key: "id", operator: "is", value: userCk.MESSAGE[0].id },
                ];

                let user = await commonObj.getData("user", { where: wr });
                console.log("auth user", user);
                if (user.SUCCESS && user.MESSAGE.id) {
                  const userBranches = await commonObj.getData("user_branch_access", { where: [
                    { key: "user_id", operator: "is", value: user.MESSAGE.id },
                  ] });
                  const branchAccessArray = userBranches.SUCCESS
                    ? userBranches.MESSAGE.map((item) => item.branch_id)
                    : [];

                  result({
                    SUCCESS: true,
                    MESSAGE: {
                      access_token: accessToken,
                      ...user.MESSAGE,
                      branch: branchAccessArray,
                    },
                  });
                } else {
                  result({ SUCCESS: false, MESSAGE: "Invalid login details!" });
                }
              } else {
                result({ SUCCESS: false, MESSAGE: "Account is not active." });
              }
            } else {
              result({ SUCCESS: false, MESSAGE: "Invalid login details!" });
            }
            // } else {
            //   result({SUCCESS:false,MESSAGE:'CAPTCHA verification failed.'});
            //   return;
            // }
          } else {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide Email ID / Phone No and Password",
            });
          }
          //type logout
        } else if (
          data.grant_type == "logout"
        ) {
          _.invalidateToken(_.decryptStr(data.token));
          result({ SUCCESS: true, MESSAGE: "ok" });
          //type update balance
        } else if (data.grant_type == "check") {
          if (data.token && data.token != "" && data.token != null) {
            const validation = _.validateAccessToken(_.decryptStr(data.token));
            // let user = await commonObj.getData('users', {where:[
            //   {key:"access_token",operator:"is", value:data.token},
            //   {key:"emp_id",operator:"is", value:data.emp_id}
            // ]});
            let wr = [{ key: "id", operator: "is", value: data.id }];

            let user = await commonObj.getData("user", { where: wr });
            if (validation.valid && user.SUCCESS && user.MESSAGE.id) {
              // let time = Math.floor(Date.now() / 1000);
              // const accessToken = _.createAccessToken(user.MESSAGE.ph);
              //   let t = await commonObj.setData('users', {
              //     id:user.MESSAGE[0].id,
              //     access_token:accessToken
              //   });
              result({
                SUCCESS: true,
                MESSAGE: {
                  ...validation.decoded,
                  ...user.MESSAGE,
                  access_token: data.token,
                },
              });
            } else {
              result({ SUCCESS: false, MESSAGE: validation.message });
            }
          } else {
            result({ SUCCESS: false, MESSAGE: "Access token not found" });
          }
        } else if (data.grant_type == "validateToken") {
          if (data.token && data.token != "" && data.token != null) {
            const validation = _.validateAccessToken(_.decryptStr(data.token));
            result({
              SUCCESS: validation.valid,
              MESSAGE: { ...validation.decoded, access_token: data.token },
            });
          } else {
            result({ SUCCESS: false, MESSAGE: "Access token not found" });
          }
        } else if (data.grant_type == "register") {
          if (!data.name || data.name == "") {
            result({ SUCCESS: false, MESSAGE: "Please provide the User Name" });
            return false;
          }
          if (
            !data.email ||
            data.email == "" ||
            !impFunction.isValidEmailStrict(data.email)
          ) {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide a valid Email ID",
            });
            return false;
          }

          if (
            !data.ph ||
            data.ph == "" ||
            !impFunction.isValidIndianPhoneNumber(data.ph)
          ) {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide a valid Phone No",
            });
            return false;
          }

          if (!(data.id && data.id != "") && (!data.pwd || data.pwd == "")) {
            result({ SUCCESS: false, MESSAGE: "Please provide the password" });
            return false;
          }

          let ifExist = await commonObj.customSQL(
            `SELECT id FROM ${config.get('db.pg.schemas')}.user WHERE (email='${data.email
            }' OR phone='${data.ph}') ` +
            (data.id && data.id != "" ? ` AND id !='${data.id}'` : ``)
          );
          if (ifExist.SUCCESS && ifExist.MESSAGE.length > 0) {
            result({
              SUCCESS: false,
              MESSAGE: "Duplicate email / phone.",
            });
            return false;
          }

          let arr = {
            name: data.name,
            phone: data.ph,
            email: data.email,
            created_by: data.created_by,
            created_at: moment().format("YYYY-MM-DD HH:mm:ss"),
            status: data.status,
            code: data.code,
            type: data.type
          };
          if (data.id && data.id != "") {
            arr["id"] = data.id;
          } else {
            arr["pwd"] = data.pwd;
          }

          let t = await commonObj.setData("user", arr);
          // if (t.SUCCESS && !(data.id && data.id != "")) {
          //   const noti = await notification.call(commonObj, {
          //     type: "send_mail",
          //     senderType: "new_user",
          //     toEmail: data.email,
          //     senderId: t.MESSAGE,
          //   });
          // }
          result({ SUCCESS: true, MESSAGE: t });
        } else if (data.grant_type == "import") {
          let resArr = [];
          for (const item of data.arr) {
            let arr = {
              name: item.name,
              phone: item.phone,
              email: item.email,
              company: item.company,
              status: 'active',
              customid: item.company + item.id,
            };
            let tmpArr = { ID_RESPONSE: item.id, SUCCESS: false };
            let ifExist = await commonObj.customSQL(
              `SELECT id FROM ${config.get(
                "db.mysql.schemas"
              )}.user WHERE (id = '${item.id}' OR email='${item.email
              }' OR phone='${item.ph}') `
            );
            if (!(ifExist.SUCCESS && ifExist.MESSAGE.length > 0)) {
              let t = await commonObj.setData("user", arr);
              tmpArr.SUCCESS = t.SUCCESS;
            }
            resArr.push(tmpArr);
          }
          result({ SUCCESS: true, MESSAGE: resArr });
        } 
      } else {
        result({ SUCCESS: false, MESSAGE: "err" });
      }
    });
  },
  createAccessToken(payload) {
    const options = { expiresIn: "1d" };
    return jwt.sign(payload, this.secretKey, options);
  },
  validateAccessToken(token) {
    if (this.tokenBlacklist.has(token)) {
      return { valid: false, message: "Token has been revoked" };
    }
    try {
      const decoded = jwt.verify(token, this.secretKey);
      return { valid: true, decoded };
    } catch (error) {
      return { valid: false, message: error.message };
    }
  },
  invalidateToken(token) {
    this.tokenBlacklist.add(token);
  },
  encryptStr(input) {
    let result = "";
    for (let i = 0; i < input.length; i++) {
      // XOR operation between each character and key character
      const charCode =
        input.charCodeAt(i) ^
        this.secretKey.charCodeAt(i % this.secretKey.length);
      // Convert the result to a 2-digit hexadecimal number and append to the result
      result += charCode.toString(16).padStart(2, "0");
    }
    // Base64 encode the result for added complexity
    return btoa(result);
  },

  decryptStr(input) {
    try {
      // Base64 decode the input
      const decodedHex = atob(input);
      let result = "";

      // Convert each 2-digit hexadecimal number back to characters
      for (let i = 0; i < decodedHex.length; i += 2) {
        const hexPair = decodedHex.substr(i, 2);
        const charCode =
          parseInt(hexPair, 16) ^
          this.secretKey.charCodeAt((i / 2) % this.secretKey.length);
        result += String.fromCharCode(charCode);
      }

      return result;
    } catch (error) {
      console.log(error);
      return input;
    }
  },
  generateSecureOTP(length = 6) {
    const digits = '0123456789';
    let otp = '';
    const bytes = crypto.randomBytes(length);
    for (let i = 0; i < length; i++) {
      otp += digits[bytes[i] % 10];
    }
    return otp;
  }
};
