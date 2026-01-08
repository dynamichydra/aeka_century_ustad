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
        if (data.grant_type == "master_pwd") {
          if (data.username && data.password) {
            // const verificationURL = `https://www.google.com/recaptcha/api/siteverify?secret=6LcXV3oqAAAAAEvwmA4556g_HZlqGpdMUmShEjLt&response=${data.token}`;
            // const response = await axios.post(verificationURL);
            // const verificationResult = response.data;
            // if (verificationResult.success && verificationResult.score > 0.5) {

            let userCk = await commonObj.customSQL(
              `SELECT id, status FROM user WHERE email='${data.username}' OR phone='${data.username}'`
            );
            if (userCk.SUCCESS && userCk.MESSAGE.length > 0) {
              if (userCk.MESSAGE[0].status == 1) {
                const accessToken = _.encryptStr(
                  _.createAccessToken({
                    type: userCk.MESSAGE[0].type == 1 ? "admin" : "user",
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
                  result({
                    SUCCESS: true,
                    MESSAGE: {
                      access_token: accessToken,
                      ...user.MESSAGE,
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
          data.grant_type == "master_logout" ||
          data.grant_type == "customer_logout" ||
          data.grant_type == "deliveryboy_logout"
        ) {
          _.invalidateToken(_.decryptStr(data.token));
          result({ SUCCESS: true, MESSAGE: "ok" });
          //type update balance
        } else if (data.grant_type == "master_check") {
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
        } else if (data.grant_type == "master_register") {
          if (!data.code || data.code == "") {
            result({ SUCCESS: false, MESSAGE: "Please provide the User ID" });
            return false;
          }
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
            `SELECT id FROM ${config.get(
              "db.mysql.schemas"
            )}.user WHERE (code = '${data.code}' OR email='${data.email
            }' OR phone='${data.ph}') ` +
            (data.id && data.id != "" ? ` AND id !='${data.id}'` : ``)
          );
          if (ifExist.SUCCESS && ifExist.MESSAGE.length > 0) {
            result({
              SUCCESS: false,
              MESSAGE: "Duplicate User ID / email / phone.",
            });
            return false;
          }

          let arr = {
            name: data.name,
            phone: data.ph,
            email: data.email,
            created_by: data.created_by,
            created_at: moment().format("YYYY-MM-DD HH:mm:ss"),
            status: parseInt(data.status),
            code: data.code,
            type: data.type
          };
          if (data.id && data.id != "") {
            arr["id"] = data.id;
          } else {
            arr["pwd"] = data.pwd;
          }

          let t = await commonObj.setData("user", arr);
          if (t.SUCCESS && !(data.id && data.id != "")) {
            const noti = await notification.call(commonObj, {
              type: "send_mail",
              senderType: "new_user",
              toEmail: data.email,
              senderId: t.MESSAGE,
            });
          }
          result({ SUCCESS: true, MESSAGE: t });
        } else if (data.grant_type == "import") {
          let resArr = [];
          for (const item of data.arr) {
            let arr = {
              name: item.name,
              phone: item.phone,
              email: item.email,
              company: item.company,
              status: 1,
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
        } else if (data.grant_type == "company") {
          if (!data.id || data.id == "") {
            result({ SUCCESS: false, MESSAGE: "Please provide the Sort Code" });
            return false;
          }
          if (!data.name || data.name == "") {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide the Company Name",
            });
            return false;
          }

          let ifExist = await commonObj.customSQL(
            `SELECT id FROM ${config.get(
              "db.mysql.schemas"
            )}.companies WHERE id = '${data.id}'  ` +
            (data.eid && data.eid != "" ? ` AND id !='${data.eid}'` : ``)
          );
          if (ifExist.SUCCESS && ifExist.MESSAGE.length > 0) {
            result({ SUCCESS: false, MESSAGE: "Duplicate Company found." });
            return false;
          }

          let arr = {
            name: data.name,
            customid: data.id,
          };
          if (data.eid && data.eid != "") {
            arr["id"] = data.eid;
          }

          let t = await commonObj.setData("companies", arr);
          result({ SUCCESS: true, MESSAGE: t });
        } else if (data.grant_type == "customer_register") {
          // if (!data.code || data.code == '') {
          //   result({ SUCCESS: false, MESSAGE: 'Please provide the Customer Code' });
          //   return false;
          // }
          if (!data.name || data.name == "") {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide the Customer Name",
            });
            return false;
          }
          if (!data.phone || data.phone == "") {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide the Customer Phone No",
            });
            return false;
          }
          if (!data.email || data.email == "") {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide the Customer Email ID",
            });
            return false;
          }

          if (!(data.id && data.id != "") && (!data.pwd || data.pwd == "")) {
            result({ SUCCESS: false, MESSAGE: "Please provide the password" });
            return false;
          }

          let ifExist = await commonObj.customSQL(
            `SELECT id FROM ${config.get(
              "db.mysql.schemas"
            )}.customer WHERE (email='${data.email}' OR phone='${data.phone
            }') ` + (data.id && data.id != "" ? ` AND id !='${data.id}'` : ``)
          );
          if (ifExist.SUCCESS && ifExist.MESSAGE.length > 0) {
            result({
              SUCCESS: false,
              MESSAGE: "Duplicate Employee ID / email / phone.",
            });
            return false;
          }

          let arr = {
            name: data.name,
            phone: data.phone,
            email: data.email,
            pwd: data.pwd,
            created_at: moment().format("YYYY-MM-DD HH:mm:ss"),
            status: parseInt(data.status) || 1,
          };
          if (data.id && data.id != "") {
            arr["id"] = data.id;
          }

          let t = await commonObj.setData("customer", arr);

          console.log(t);

          result({ SUCCESS: true, MESSAGE: t });
        } else if (data.grant_type == "customer_pwd") {
          if (data.username && data.password) {
            let userCk = await commonObj.customSQL(
              `SELECT id, status FROM customer WHERE email='${data.username}' OR phone='${data.username}'`
            );
            if (userCk.SUCCESS && userCk.MESSAGE.length > 0) {
              if (userCk.MESSAGE[0].status == 1) {
                const accessToken = _.encryptStr(
                  _.createAccessToken({
                    type: "customer",
                    userId: data.username,
                    id: userCk.MESSAGE[0].id,
                  })
                );
                let wr = [
                  { key: "pwd", operator: "is", value: data.password },
                  { key: "id", operator: "is", value: userCk.MESSAGE[0].id },
                ];

                let user = await commonObj.getData("customer", { where: wr });
                console.log("auth customer", user);
                if (user.SUCCESS && user.MESSAGE.id) {
                  result({
                    SUCCESS: true,
                    MESSAGE: {
                      access_token: accessToken,
                      ...user.MESSAGE,
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
        } else if (data.grant_type == "customer_check") {
          if (data.token && data.token != "" && data.token != null) {
            const validation = _.validateAccessToken(_.decryptStr(data.token));
            // let user = await commonObj.getData('users', {where:[
            //   {key:"access_token",operator:"is", value:data.token},
            //   {key:"emp_id",operator:"is", value:data.emp_id}
            // ]});
            let wr = [{ key: "id", operator: "is", value: data.id }];

            let user = await commonObj.getData("customer", { where: wr });
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
        } else if (data.grant_type == "deliveryboy_pwd") {
          if (data.username && data.password) {
            let userCk = await commonObj.customSQL(
              `SELECT id, status FROM delivery_boy WHERE email='${data.username}' OR phone='${data.username}'`
            );
            if (userCk.SUCCESS && userCk.MESSAGE.length > 0) {
              if (userCk.MESSAGE[0].status == 1) {
                const accessToken = _.encryptStr(
                  _.createAccessToken({
                    type: "delivery_boy",
                    userId: data.username,
                    id: userCk.MESSAGE[0].id,
                  })
                );
                let wr = [
                  { key: "pwd", operator: "is", value: data.password },
                  { key: "id", operator: "is", value: userCk.MESSAGE[0].id },
                ];

                let user = await commonObj.getData("delivery_boy", {
                  where: wr,
                });
                console.log("auth delivery_boy", user);
                if (user.SUCCESS && user.MESSAGE.id) {
                  result({
                    SUCCESS: true,
                    MESSAGE: {
                      access_token: accessToken,
                      ...user.MESSAGE,
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
        } else if (data.grant_type == "deliveryboy_check") {
          if (data.token && data.token != "" && data.token != null) {
            const validation = _.validateAccessToken(_.decryptStr(data.token));
            // let user = await commonObj.getData('users', {where:[
            //   {key:"access_token",operator:"is", value:data.token},
            //   {key:"emp_id",operator:"is", value:data.emp_id}
            // ]});
            let wr = [{ key: "id", operator: "is", value: data.id }];

            let user = await commonObj.getData("delivery_boy", { where: wr });
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
        } else if (data.grant_type == "brancheuser_pwd") {
          if (data.username && data.password) {
            let userCk = await commonObj.customSQL(
              `SELECT id, status FROM branche_user WHERE email='${data.username}' OR phone='${data.username}'`
            );
            if (userCk.SUCCESS && userCk.MESSAGE.length > 0) {
              if (userCk.MESSAGE[0].status == 1) {
                const accessToken = _.encryptStr(
                  _.createAccessToken({
                    type: "branche_user",
                    userId: data.username,
                    id: userCk.MESSAGE[0].id,
                  })
                );
                let wr = [
                  { key: "pwd", operator: "is", value: data.password },
                  { key: "id", operator: "is", value: userCk.MESSAGE[0].id },
                ];

                let user = await commonObj.getData("branche_user", { where: wr });
                if (user.SUCCESS && user.MESSAGE.id) {
                  result({
                    SUCCESS: true,
                    MESSAGE: {
                      access_token: accessToken,
                      ...user.MESSAGE,
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
          } else {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide Email ID / Phone No and Password",
            });
          }
        } else if (data.grant_type == "brancheuser_check") {
          if (data.token && data.token != "" && data.token != null) {
            const validation = _.validateAccessToken(_.decryptStr(data.token));
            let wr = [{ key: "id", operator: "is", value: data.id }];

            let user = await commonObj.getData("branche_user", { where: wr });
            if (validation.valid && user.SUCCESS && user.MESSAGE.id) {
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
        } else if (data.grant_type == "reset_password") {
          if (data.email && data.reset_for) {
            //  check custmer is exsis or not 
            let wr = [{ key: "email", operator: "is", value: data.email }];

            let custmer = await commonObj.getData(data.reset_for, { where: wr });
            if (custmer.SUCCESS && custmer.MESSAGE.length && custmer.MESSAGE[0].id) {
              let t = await commonObj.setData(data.reset_for, {
                reset_otp: _.generateSecureOTP(),
                id: custmer.MESSAGE[0].id,
                reset_otp_time: moment().format("YYYY-MM-DD HH:mm:ss"),
              }); 
              const noti = await notification.call(commonObj, {
                type: "send_mail",
                senderType: data.reset_for == 'customer' ? "fPwd_customer" : "fPwd_delivery",
                toEmail: data.email,
                senderId: custmer.MESSAGE[0].id,
              });
              if (!noti.SUCCESS) {
                console.log(noti);

                result({ SUCCESS: false, MESSAGE: noti?.MESSAGE?.response });
              } else {
                result({ SUCCESS: true, MESSAGE: 'Email send successfully' });
              }

            } else {
              result({
                SUCCESS: false,
                MESSAGE: "User Not found!",
              });
            }
          } else {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide Email ID and reset for",
            });
          }
        } else if (data.grant_type == "set_password") {
          if (data.email && data.password && data.reset_otp && data.set_for) {
            //  check custmer is exsis or not 
            let wr = [{ key: "email", operator: "is", value: data.email }];

            let custmer = await commonObj.getData(data.set_for, { where: wr });
            if (custmer.SUCCESS && custmer.MESSAGE.length && custmer.MESSAGE[0].id) {
              // check enter otp and customer DB otp is equal
              if (parseInt(data.reset_otp) !== custmer.MESSAGE[0].reset_otp) {
                result({
                  SUCCESS: false,
                  MESSAGE: "OTP not match",
                });
                return false;
              }
              // check current time and reset_otp_time is less than 15min
              const rTime = moment(custmer.MESSAGE[0].reset_otp_time, "HH:mm:ss");
              const now = moment();
              const diffInMinutes = now.diff(rTime, 'minutes');

              if (parseInt(diffInMinutes)>15) {
                result({
                  SUCCESS: false,
                  MESSAGE: "OTP Sesion expire",
                });
                return false;
              }
              // set customer password
              let t = await commonObj.setData(data.set_for, {
                id: custmer.MESSAGE[0].id,
                pwd:data.password
              });

              if (t.SUCCESS) {
                result({
                  SUCCESS: true,
                  MESSAGE: "Password Reset Successfully",
                });
              }else{
                result({
                  SUCCESS: true,
                  MESSAGE: t.MESSAGE,
                });
              }

            } else {
              result({
                SUCCESS: false,
                MESSAGE: "User Not Found!",
              });
            }
          } else {
            result({
              SUCCESS: false,
              MESSAGE: "Please provide email ID / reset otp / new password / set for ",
            });
          }
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
