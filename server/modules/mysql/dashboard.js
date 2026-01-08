const config = require('config');
exports.init = {

    call: async function (commonObj, data) {
        let _ = this;
        const dashboard = config.get('dashboard');

        return new Promise(async function (result) {
            if (data) {
                const dashboardData = [];
                for (let i = 0; i < dashboard.length; i++) {
                    const element = dashboard[i];
                    if (element.type == 'card') {
                       let sql =  `SELECT
                            COUNT(*) AS total,
                            COUNT(CASE WHEN status = '1' THEN 1 END) AS active,
                            COUNT(CASE WHEN status = '0' THEN 1 END) AS inactive
                        FROM ${element.name} WHERE 1`
                        if (data.branche_id || data.branche_id !=='') {
                            if (element.name == 'delivery_boy') {
                                sql +=` AND branche = ${data.branche_id}`
                            } else if (element.name == 'user'){
                                sql += ` AND branche_id = ${data.branche_id}`
                            }
                        }else{
                            if (element.name == 'user') {
                                sql += ` AND type = '2' `
                            }
                        }
                        let res = await commonObj.customSQL(sql);
                        if (res.SUCCESS) {
                            element.data = res.MESSAGE;
                            dashboardData.push(element)
                        }else{
                            element.data = [];
                            dashboardData.push(element) 
                        }
                    } else if (element.type == 'table') {
                        let res = await commonObj.getData(`${element.name}`,{
                            limit:{ total: 5, offset: 0 },
                            order:{ type: "DESC", by: "consignment.id" }
                        });
                        if (res.SUCCESS) {
                            element.data = res.MESSAGE;
                            dashboardData.push(element)
                        } else {
                            element.data = [];
                            dashboardData.push(element)
                        }
                    }
                    
                }
                result({ SUCCESS: true, MESSAGE: dashboardData});
            } else {
                result({ SUCCESS: false, MESSAGE: 'No type defined' });
            }
        });
    },
};