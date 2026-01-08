const jwt = require('jsonwebtoken');
const config = require('config');
const moment = require('moment');

exports.init = {
    secretKey: 'Sharow72$0q!3lddYrnb>u0',
    tokenBlacklist: new Set(),

    call: async function (commonObj, data) {
        if (!data || !data.grant_type) {
            return { SUCCESS: false, MESSAGE: 'Invalid request' };
        }

        const handler = this.getHandler(data.grant_type);
        if (!handler) return { SUCCESS: false, MESSAGE: 'Unsupported grant_type' };

        try {
            return await handler.call(this, commonObj, data);
        } catch (error) {
            console.error("Auth Error:", error);
            return { SUCCESS: false, MESSAGE: 'Internal server error' };
        }
    },

    getHandler(grantType) {
        const handlers = {
            master_pwd: this.handleLogin('user', 'admin'),
            customer_pwd: this.handleLogin('customer', 'customer'),
            deliveryboy_pwd: this.handleLogin('delivery_boy', 'delivery_boy'),
            master_check: this.handleCheck('user'),
            customer_check: this.handleCheck('customer'),
            deliveryboy_check: this.handleCheck('delivery_boy'),
            master_logout: this.handleLogout,
            customer_logout: this.handleLogout,
            deliveryboy_logout: this.handleLogout,
            validateToken: this.handleTokenValidation,
            master_register: this.handleMasterRegister,
            import: this.handleImport,
            company: this.handleCompany
        };

        return handlers[grantType];
    },

    handleLogin(table, role) {
        return async function (commonObj, data) {
            const { username, password } = data;
            if (!username || !password) {
                return { SUCCESS: false, MESSAGE: 'Please provide Email ID / Phone No and Password' };
            }

            const userQuery = `SELECT id, status FROM ${table} WHERE email='${username}' OR phone='${username}'`;
            const userCheck = await commonObj.customSQL(userQuery);
            const user = userCheck?.MESSAGE?.[0];

            if (!user || user.status !== 1) {
                return { SUCCESS: false, MESSAGE: 'Invalid login details or inactive account' };
            }

            const where = [
                { key: "pwd", operator: "is", value: password },
                { key: "id", operator: "is", value: user.id }
            ];
            const userData = await commonObj.getData(table, { where });

            if (!userData?.SUCCESS || !userData.MESSAGE?.id) {
                return { SUCCESS: false, MESSAGE: 'Invalid login details!' };
            }

            const payload = { type: role, userId: username, id: user.id };
            const accessToken = this.encryptStr(this.createAccessToken(payload));

            return { SUCCESS: true, MESSAGE: { access_token: accessToken, ...userData.MESSAGE } };
        };
    },

    handleLogout: async function (commonObj, data) {
        const token = data.token;
        if (token) this.invalidateToken(this.decryptStr(token));
        return { SUCCESS: true, MESSAGE: 'Logged out successfully' };
    },

    handleCheck(table) {
        return async function (commonObj, data) {
            const token = data.token;
            if (!token) return { SUCCESS: false, MESSAGE: 'Access token not found' };

            const decrypted = this.decryptStr(token);
            const validation = this.validateAccessToken(decrypted);
            if (!validation.valid) return { SUCCESS: false, MESSAGE: validation.message };

            const user = await commonObj.getData(table, { where: [{ key: "id", operator: "is", value: data.id }] });
            if (!user?.SUCCESS || !user.MESSAGE?.id) return { SUCCESS: false, MESSAGE: 'User not found' };

            return { SUCCESS: true, MESSAGE: { ...validation.decoded, ...user.MESSAGE, access_token: token } };
        };
    },

    handleTokenValidation: async function (_, data) {
        const token = data.token;
        if (!token) return { SUCCESS: false, MESSAGE: 'Access token not found' };

        const decrypted = this.decryptStr(token);
        const validation = this.validateAccessToken(decrypted);
        return { SUCCESS: validation.valid, MESSAGE: { ...validation.decoded, access_token: token } };
    },

    handleMasterRegister: async function (commonObj, data) {
        const requiredFields = ['code', 'name', 'ph', 'email', 'company'];
        for (const field of requiredFields) {
            if (!data[field]) return { SUCCESS: false, MESSAGE: `Please provide the ${field}` };
        }
        if (!data.id && !data.pwd) return { SUCCESS: false, MESSAGE: 'Please provide the password' };

        const schema = config.get('db.mysql.schemas');
        const dupCheckSQL = `SELECT id FROM ${schema}.user WHERE (code = '${data.code}' OR email='${data.email}' OR phone='${data.ph}')` + (data.id ? ` AND id !='${data.id}'` : ``);
        const exists = await commonObj.customSQL(dupCheckSQL);
        if (exists?.MESSAGE?.length > 0) {
            return { SUCCESS: false, MESSAGE: 'Duplicate Employee ID / email / phone.' };
        }

        const record = {
            id: data.id,
            name: data.name,
            phone: data.ph,
            email: data.email,
            company: data.company,
            code: data.code,
            pwd: data.pwd,
            created_by: data.created_by,
            created_at: moment().format('YYYY-MM-DD HH:mm:ss'),
            status: parseInt(data.status) || 1
        };

        const save = await commonObj.setData('user', record);
        return { SUCCESS: true, MESSAGE: save };
    },

    handleImport: async function (commonObj, data) {
        const schema = config.get('db.mysql.schemas');
        const results = [];

        for (const item of data.arr) {
            const tmpResult = { ID_RESPONSE: item.id, SUCCESS: false };
            const checkSQL = `SELECT id FROM ${schema}.user WHERE (id = '${item.id}' OR email='${item.email}' OR phone='${item.ph}')`;
            const exists = await commonObj.customSQL(checkSQL);

            if (!exists?.MESSAGE?.length) {
                const newUser = {
                    name: item.name,
                    phone: item.phone,
                    email: item.email,
                    company: item.company,
                    status: 1,
                    customid: item.company + item.id
                };
                const save = await commonObj.setData('user', newUser);
                tmpResult.SUCCESS = save.SUCCESS;
            }

            results.push(tmpResult);
        }

        return { SUCCESS: true, MESSAGE: results };
    },

    handleCompany: async function (commonObj, data) {
        const { id, name, eid } = data;
        if (!id || !name) return { SUCCESS: false, MESSAGE: 'Please provide valid company data' };

        const schema = config.get('db.mysql.schemas');
        const dupCheckSQL = `SELECT id FROM ${schema}.companies WHERE id = '${id}'` + (eid ? ` AND id != '${eid}'` : '');
        const exists = await commonObj.customSQL(dupCheckSQL);
        if (exists?.MESSAGE?.length > 0) return { SUCCESS: false, MESSAGE: 'Duplicate Company found.' };

        const company = { id: eid, name, customid: id };
        const save = await commonObj.setData('companies', company);
        return { SUCCESS: true, MESSAGE: save };
    },

    createAccessToken(payload) {
        return jwt.sign(payload, this.secretKey, { expiresIn: '30m' });
    },

    validateAccessToken(token) {
        if (this.tokenBlacklist.has(token)) {
            return { valid: false, message: 'Token has been revoked' };
        }
        try {
            const decoded = jwt.verify(token, this.secretKey);
            return { valid: true, decoded };
        } catch (err) {
            return { valid: false, message: err.message };
        }
    },

    invalidateToken(token) {
        this.tokenBlacklist.add(token);
    },

    encryptStr(input) {
        let result = '';
        for (let i = 0; i < input.length; i++) {
            const charCode = input.charCodeAt(i) ^ this.secretKey.charCodeAt(i % this.secretKey.length);
            result += charCode.toString(16).padStart(2, '0');
        }
        return Buffer.from(result).toString('base64');
    },

    decryptStr(input) {
        try {
            const hex = Buffer.from(input, 'base64').toString();
            let result = '';
            for (let i = 0; i < hex.length; i += 2) {
                const hexPair = hex.substr(i, 2);
                const charCode = parseInt(hexPair, 16) ^ this.secretKey.charCodeAt((i / 2) % this.secretKey.length);
                result += String.fromCharCode(charCode);
            }
            return result;
        } catch (err) {
            console.log("Decrypt error:", err);
            return input;
        }
    }
};
