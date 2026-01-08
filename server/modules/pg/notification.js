const config = require('config');
const EmailService = require('../../service/emailService');
const path = require('path');
exports.init = {

    call: async function (commonObj, data) {
        let _ = this;
        const notification = config.get('notification');

        return new Promise(async function (result) {
            if (data) {
                //get notification fields
                if (data.type == 'get_fields') {
                    result({ SUCCESS: true, MESSAGE: { field: notification.template_field, type: notification.type } });
                } else if (data.type == 'send_mail') {
                    const res = await sendEmail(commonObj, data, notification);
                    result(res);
                }
            } else {
                result({ SUCCESS: false, MESSAGE: 'No type defined' });
            }
        });
    },
};

async function sendEmail(commonObj, data, notification) {
    try {
        const template = await fetchNotificationTemplate(commonObj, data.senderType);
        if (!template) return { SUCCESS: false, MESSAGE: 'Notification template not found' };

        let emailBody = decodeBase64(template.body);
        const placeholders = extractPlaceholders(emailBody);
        data = await fillPlaceholders(emailBody, placeholders, data, notification, commonObj);

        data.toEmail = [];

        // Workflow mapping
        const workflowRecipients = {
            samplerequest: async () => {
                // Influencer
                const influencer = await commonObj.getData('influencer', {
                    where: [{ key: 'id', operator: 'is', value: data.influencerId }]
                });
                if (influencer.MESSAGE?.email) data.toEmail.push(influencer.MESSAGE.email);

                // Branch users
                const branchUsers = await commonObj.getData('user', {
                    where: [{ key: 'branch', operator: 'is', value: data.branchId }, { key: 'type', operator: 'is', value: 'BAT' }]
                });
                if (branchUsers.SUCCESS) branchUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));
            },

            orderStatus: async () => {
                if (data.sendBy === 'PMG') {
                    // Branch users
                    const branchUsers = await commonObj.getData('user', {
                        where: [{ key: 'branch', operator: 'is', value: data.branchId },
                        { key: 'type', operator: 'is', value: 'BAT' }
                        ]
                    });

                    if (branchUsers.SUCCESS) branchUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));

                    // Commercial users
                    const commercialUsers = await commonObj.getData('user', {
                        where: [{ key: 'type', operator: 'is', value: 'Commercial' }]
                    });

                    if (commercialUsers.SUCCESS) commercialUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));
                }

                if (data.sendBy === 'Commercial') {
                    // Factory users
                    const factoryUsers = await commonObj.getData('user', {
                        where: [{ key: 'type', operator: 'is', value: 'Factory' }]
                    });
                    if (factoryUsers.SUCCESS) factoryUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));

                    // PMG users
                    const pmgUsers = await commonObj.getData('user', {
                        where: [{ key: 'type', operator: 'is', value: 'PMG' }]
                    });
                    if (pmgUsers.SUCCESS) pmgUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));
                }

                if (data.sendBy === 'Factory') {
                    // Commercial users
                    const commercialUsers = await commonObj.getData('user', {
                        where: [{ key: 'type', operator: 'is', value: 'Commercial' }]
                    });
                    if (commercialUsers.SUCCESS) commercialUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));

                    // Branch users
                    const branchUsers = await commonObj.getData('user', {
                        where: [{ key: 'branch', operator: 'is', value: data.branchId }, { key: 'type', operator: 'is', value: 'BAT' }]
                    });
                    if (branchUsers.SUCCESS) branchUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));
                }

                if (data.sendBy === 'BAT') {
                    // Factory users
                    const factoryUsers = await commonObj.getData('user', {
                        where: [{ key: 'type', operator: 'is', value: 'Factory' }]
                    });
                    if (factoryUsers.SUCCESS) factoryUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));

                    // Branch users
                    const branchUsers = await commonObj.getData('user', {
                        where: [{ key: 'branch', operator: 'is', value: data.branchId },
                        { key: 'type', operator: 'is', value: 'BAT' }]
                    });
                    if (branchUsers.SUCCESS) branchUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));
                }
            }
        };

        if (workflowRecipients[data.sendType]) {
            await workflowRecipients[data.sendType]();
        } else {
            if (!data.toEmail.length) return { SUCCESS: false, MESSAGE: 'Recipient email not found' };
        }

        const settings = await getSystemSettings(commonObj);
        if (!settings) return { SUCCESS: false, MESSAGE: 'No system settings available in database' };

        const emailService = new EmailService(settings.email_api, settings);

        const emailResponse = await emailService.sendEmail({
          from: settings.sender_email,
          to: data.toEmail,
          subject: `${template.subject} ${data.status??''}`,
          html: data.filledBody,
        });
        return emailResponse;
    } catch (error) {
        console.error('Error in sendEmail:', error);
        return { SUCCESS: false, MESSAGE: error.toString() };
    }
}

async function fetchNotificationTemplate(commonObj, senderType) {
    const res = await commonObj.getData('notification_template', {
        where: [{ key: 'type', operator: 'is', value: senderType }]
    });

    return res.SUCCESS && res.MESSAGE.length ? res.MESSAGE[0] : null;
}

function decodeBase64(encodedStr) {
    return Buffer.from(encodedStr, 'base64').toString('utf-8');
}

function extractPlaceholders(templateBody) {
    return [...templateBody.matchAll(/%#%(.+?)%#%/g)].map(match => match[1]);
}

async function fillPlaceholders(body, placeholders, data, notification, commonObj) {
    for (const placeholder of placeholders) {
        const fieldInfo = notification.template_field[placeholder];
        if (!fieldInfo || !fieldInfo.used.includes(data.senderType)) continue;

        const tableName = fieldInfo.table;
        const fieldName = fieldInfo.field;

        const res = await commonObj.getData(tableName, {
            where: [{ key: 'id', operator: 'is', value: data.senderId }]
        });

        if (!res.SUCCESS) throw new Error(`Data not found for placeholder: ${placeholder}`);

        const actualValue = res.MESSAGE[fieldName];
        if (!actualValue) throw new Error(`Missing value for placeholder: ${placeholder}`);

        const regex = new RegExp(`%#%${placeholder}%#%`, 'g');
        body = body.replace(regex, actualValue);

        if (!data.toEmail && res.MESSAGE.email) {
            data.toEmail = res.MESSAGE.email;
        }
    }

    data.filledBody = body;
    return data;
}

async function getSystemSettings(commonObj) {
    const res = await commonObj.getData('settings', {});
    return res.SUCCESS && res.MESSAGE.length ? res.MESSAGE[0] : null;
}