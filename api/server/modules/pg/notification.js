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
                    let res = null;
                    if (data.sendingType == 'sample_request_notification') {
                        res = await sendSampleRequestNotification(commonObj, data, notification);
                    } else if (data.sendingType == 'order_status_notification') {
                        res = await sendOrderStatusNotification(commonObj, data, notification);
                    } else if (data.sendingType == 'sample_request_approve'){
                        res = await sendSampleRequestApproveNotification(commonObj, data, notification);
                    } else {
                        res = await sendEmail(commonObj, data, notification);
                    }
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
                const branchUsers = await commonObj.getData("user u", {
                    where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
                    reference: [
                        {
                            type: "LEFT JOIN",
                            obj: "user_branch_access uba",
                            a: "uba.user_id",
                            b: "u.id",
                        },
                    ],
                    select: "u.email email",
                });

                if (branchUsers.SUCCESS)
                    branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));
                if (branchUsers.SUCCESS) branchUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));
            },

            orderStatus: async () => {
                if (data.sendBy === 'PMG') {
                    // Branch users
                    const branchUsers = await commonObj.getData("user u", {
                        where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
                        reference: [
                            {
                                type: "LEFT JOIN",
                                obj: "user_branch_access uba",
                                a: "uba.user_id",
                                b: "u.id",
                            },
                        ],
                        select: "u.email email",
                    });

                    if (branchUsers.SUCCESS)
                        branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));

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
                    const branchUsers = await commonObj.getData("user u", {
                        where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
                        reference: [
                            {
                                type: "LEFT JOIN",
                                obj: "user_branch_access uba",
                                a: "uba.user_id",
                                b: "u.id",
                            },
                        ],
                        select: "u.email email",
                    });

                    if (branchUsers.SUCCESS)
                        branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));
                }

                if (data.sendBy === 'BAT') {
                    // Factory users
                    const factoryUsers = await commonObj.getData('user', {
                        where: [{ key: 'type', operator: 'is', value: 'Factory' }]
                    });
                    if (factoryUsers.SUCCESS) factoryUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));

                    // Branch users
                    const branchUsers = await commonObj.getData("user u", {
                        where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
                        reference: [
                            {
                                type: "LEFT JOIN",
                                obj: "user_branch_access uba",
                                a: "uba.user_id",
                                b: "u.id",
                            },
                        ],
                        select: "u.email email",
                    });

                    if (branchUsers.SUCCESS)
                        branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));
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
            cc: settings.email_cc,
            subject: `${template.subject} ${data.status ?? ''}`,
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


async function sendSampleRequestNotification(commonObj, data, notification) {
    const productsWithDetails = [];
    for (const item of data.products) {
        const productRes = await commonObj.getData("product", {
            where: [{ key: "id", operator: "is", value: item.product }],
            select: "id, name, sku_no",
        });

        if (productRes.SUCCESS && productRes.MESSAGE) {
            const p = productRes.MESSAGE;
            productsWithDetails.push({
                id: p.id,
                name: p.name,
                sku: p.sku_no,
                qnt: item.quantity,
            });
        }
    }

    data.products = productsWithDetails;
    data.toEmail = [];

    const influencer = await commonObj.getData("influencer", {
        where: [{ key: "id", operator: "is", value: data.influencer_id }],
    });
    if (influencer.MESSAGE?.email) {
        data.toEmail.push(influencer.MESSAGE.email);
        data.receiverName = influencer.MESSAGE.name;
    }

    const project = await commonObj.getData("project", {
        where: [{ key: "id", operator: "is", value: data.project_id }],
    });
    if (project.MESSAGE?.lead_no) {
        data.leadNo = project.MESSAGE.lead_no;
    }

    const branchUsers = await commonObj.getData("user u", {
        where: [{ key: "uba##branch_id", value: data.branchId, operator: "is" }],
        reference: [
            {
                type: "LEFT JOIN",
                obj: "user_branch_access uba",
                a: "uba.user_id",
                b: "u.id",
            },
        ],
        select: "u.email email",
    });

    if (branchUsers.SUCCESS)
        branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));

    const settings = await getSystemSettings(commonObj);
    if (!settings)
        return { SUCCESS: false, MESSAGE: "No system settings available in database" };

    const template = await fetchNotificationTemplate(commonObj, 'newSampleRequest');
    if (!template) return { SUCCESS: false, MESSAGE: 'Notification template not found' };

    let emailBody = decodeBase64(template.body);
    const htmlStructer = generateSampleHtmlFromText(emailBody, data);

    const emailService = new EmailService(settings.email_api, settings);
    const emailResponse = await emailService.sendEmail({
        from: settings.sender_email,
        to: data.toEmail,
        cc: settings.email_cc,
        subject: template.subject,
        html: htmlStructer,
    });
    return emailResponse;
}

async function sendOrderStatusNotification(commonObj, data, notification) {

    data.toEmail = [];
    if (data.sendBy === 'PMG') {
        // Branch users
        const branchUsers = await commonObj.getData("user u", {
            where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
            reference: [
                {
                    type: "LEFT JOIN",
                    obj: "user_branch_access uba",
                    a: "uba.user_id",
                    b: "u.id",
                },
            ],
            select: "u.email email",
        });

        if (branchUsers.SUCCESS)
            branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));

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
        const branchUsers = await commonObj.getData("user u", {
            where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
            reference: [
                {
                    type: "LEFT JOIN",
                    obj: "user_branch_access uba",
                    a: "uba.user_id",
                    b: "u.id",
                },
            ],
            select: "u.email email",
        });

        if (branchUsers.SUCCESS)
            branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));
    }

    if (data.sendBy === 'BAT') {
        // Factory users
        const factoryUsers = await commonObj.getData('user', {
            where: [{ key: 'type', operator: 'is', value: 'Factory' }]
        });
        if (factoryUsers.SUCCESS) factoryUsers.MESSAGE.forEach(u => data.toEmail.push(u.email));

        // Branch users
        const branchUsers = await commonObj.getData("user u", {
            where: [{ key: "uba##branch_id", value: data.branch_id, operator: "is" }, { key: "u##type", value: 'BAT', operator: "is" }],
            reference: [
                {
                    type: "LEFT JOIN",
                    obj: "user_branch_access uba",
                    a: "uba.user_id",
                    b: "u.id",
                },
            ],
            select: "u.email email",
        });

        if (branchUsers.SUCCESS)
            branchUsers.MESSAGE.forEach((u) => data.toEmail.push(u.email));
    }


    const settings = await getSystemSettings(commonObj);
    if (!settings)
        return { SUCCESS: false, MESSAGE: "No system settings available in database" };

    const template = await fetchNotificationTemplate(commonObj, 'orderStatus');
    if (!template) return { SUCCESS: false, MESSAGE: 'Notification template not found' };

    let emailBody = decodeBase64(template.body);
    const htmlStructer = generateOrderHtmlFromText(emailBody, data);

    const emailService = new EmailService(settings.email_api, settings);
    const emailResponse = await emailService.sendEmail({
        from: settings.sender_email,
        to: data.toEmail,
        cc: settings.email_cc,
        subject: template.subject,
        html: htmlStructer,
    });
    return emailResponse;
}

async function sendSampleRequestApproveNotification(commonObj, data, notification) {
    const productsWithDetails = [];
    for (const item of data.products) {
        console.log(data.products);
        
        const productRes = await commonObj.getData("product", {
            where: [{ key: "id", operator: "is", value: item.prod_id }],
            select: "id, name, sku_no",
        });

        if (productRes.SUCCESS && productRes.MESSAGE) {
            const p = productRes.MESSAGE;
            productsWithDetails.push({
                id: p.id,
                name: p.name,
                sku: p.sku_no,
                qnt: item.proceedAmount,
            });
        }
    }

    data.products = productsWithDetails;
    data.toEmail = [];

    const project = await commonObj.getData("sample_request sr", {
        where: [{ key: "sr##id", operator: "is", value: data.sample_request_id }],
        reference: [
            {
                type: "JOIN",
                obj: "project p",
                a: "p.id",
                b: "sr.project_id",
            },
            {
                type: "JOIN",
                obj: "user u",
                a: "u.id",
                b: "sr.request_by",
            },
        ],
        select: "p.lead_no lead_no, u.name receivername, u.email receiveremail",
    });
    console.log(project);
    
    if (project.MESSAGE.length) {
        data.leadNo = project.MESSAGE[0].lead_no;
        data.receiverName = project.MESSAGE[0].receivername;
        data.toEmail.push(project.MESSAGE[0].receiveremail)
    }

    const settings = await getSystemSettings(commonObj);
    if (!settings)
        return { SUCCESS: false, MESSAGE: "No system settings available in database" };

    const template = await fetchNotificationTemplate(commonObj, 'sampleRequestApprove');
    if (!template) return { SUCCESS: false, MESSAGE: 'Notification template not found' };

    let emailBody = decodeBase64(template.body);
    const htmlStructer = generateSampleHtmlFromText(emailBody, data);

    const emailService = new EmailService(settings.email_api, settings);
    const emailResponse = await emailService.sendEmail({
        from: settings.sender_email,
        to: data.toEmail,
        cc: settings.email_cc,
        subject: template.subject,
        html: htmlStructer,
    });
    return emailResponse;
}

function generateSampleHtmlFromText(template, data) {
    const loopRegex = /%#%loop%#%([\s\S]*?)%#%loop_end%#%/;
    const loopMatch = template.match(loopRegex);
    let loopHTML = "";

    if (loopMatch) {
        const loopText = loopMatch[1].trim();
        loopHTML = data.products
            .map((product) =>
                loopText
                    .replace(/%#%Product Name%#%/g, product.name)
                    .replace(/%#%Product SKU%#%/g, product.sku)
                    .replace(/%#%Product Qnt%#%/g, product.qnt)
            )
            .join("<br>");
    }

    let processed = template
        .replace(loopRegex, loopHTML)
        .replace(/%#%receiver Name%#%/g, data.receiverName)
        .replace(/%#%User Name%#%/g, data.userName)
        .replace(/%#%Lead No%#%/g, data.leadNo)
        .trim();

    // --- Convert text to HTML paragraphs ---
    const htmlBody = processed
        .split(/\n\s*\n/) // split into paragraphs by blank lines
        .map((para) =>
            `<p style="margin:0 0 12px 0;">${para.replace(/\n/g, "<br>")}</p>`
        )
        .join("");

    // --- Wrap into HTML structure ---
    const html = `
  <html>
  <body style="font-family: Arial, sans-serif; color:#333; line-height:1.6; background:#f9f9f9; padding:20px;">
    <div style="max-width:600px; margin:auto; background:#fff; border-radius:8px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,0.1);">
      ${htmlBody}
    </div>
  </body>
  </html>
  `;

    return html;
}

function generateOrderHtmlFromText(template, data) {
    let processed = template
        .replace(/%#%receiver Name%#%/g, data.receiverName)
        .replace(/%#%User Name%#%/g, data.userName)
        .replace(/%#%Order No%#%/g, data.orderNo)
        .replace(/%#%Product Name%#%/g, data.productName)
        .replace(/%#%Product SKU%#%/g, data.productSku)
        .replace(/%#%Status%#%/g, data.status)
        .replace(/%#%Product Qnt%#%/g, data.productQnt)
        .replace(/%#%Notes%#%/g, data.notes)
        .trim();

    const htmlBody = processed
        .split(/\n\s*\n/)
        .map((para) =>
            `<p style="margin:0 0 12px 0;">${para.replace(/\n/g, "<br>")}</p>`
        )
        .join("");
    const html = `
  <html>
  <body style="font-family: Arial, sans-serif; color:#333; line-height:1.6; background:#f9f9f9; padding:20px;">
    <div style="max-width:600px; margin:auto; background:#fff; border-radius:8px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,0.1);">
      ${htmlBody}
    </div>
  </body>
  </html>
  `;

    return html;
}