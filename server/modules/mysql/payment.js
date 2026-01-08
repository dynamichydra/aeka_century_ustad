const PaymentService = require("../../service/paymentService");
const InvoiceService = require("../../service/InvoiceService");
// const EmailService = require("../../service/EmailService");

exports.init = {
    call: async function (commonObj, data) {
        const res = await commonObj.getData('payment_settings',{});
        const paymentSettings =  res.SUCCESS && res.MESSAGE.length ? res.MESSAGE[0] : null;
        if (!paymentSettings) return { SUCCESS: false, MESSAGE: 'Payment Setting not found' };
        
        const payment = new PaymentService(paymentSettings);        
        try {
            switch (data.grant_type) {
                case "initiate": {
                    if (!data.consignment_id) {
                        return { SUCCESS: false, MESSAGE: 'Please provied consignment id' };
                    }
                    //  check consignment avalable and paymnet is not done
                    const res = await commonObj.getData('consignment',{
                        where:[
                            { 'key': 'id', 'operator': 'id', 'value': data.consignment_id } 
                        ]
                    });
                    if (!res.SUCCESS) {
                        return { SUCCESS: false, MESSAGE: res.MESSAGE }; 
                    }
                    const consignment = res.MESSAGE;
                    if (consignment.payment_status == 2 ) {
                        return { SUCCESS: true, MESSAGE: 'Payment already done' }; 
                    }
                    console.log(Number(consignment.parcel_cost));
                    
                    const initData = {
                        currency: "INR",
                        amount: Number(consignment.parcel_cost)
                    }
                    const result = await payment.initiate(commonObj, initData);
                    return { SUCCESS: true, MESSAGE: result };
                }

                case "verifypayment": {
                    const verified = await payment.verify(data);
                    console.log(verified);
                    
                    return verified
                        ? { SUCCESS: true, MESSAGE: "Payment verified" }
                        : { SUCCESS: false, MESSAGE: "Payment verification failed" };
                }

                case "confirm":
                case "manual_confirm":
                case "failed":
                    return await this.handleOrderConfirmation(commonObj, data);

                default:
                    return { SUCCESS: false, MESSAGE: "Unknown grant_type" };
            }
        } catch (err) {
            console.error("PaymentService error:", err);
            return { SUCCESS: false, MESSAGE: err.message };
        }
    },

    handleOrderConfirmation: async function (commonObj, data) {
        const order = await commonObj.getData("order", {
            where: [
                { key: "order_no", operator: "is", value: data.order_no },
                { key: "emp_id", operator: "is", value: data.emp_id },
            ],
        });

        if (!order.SUCCESS || order.MESSAGE.length === 0) {
            return { SUCCESS: false, MESSAGE: "Order not found" };
        }

        const orderId = order.MESSAGE[0].id;

        await commonObj.setData("order", {
            ref_no: data.ref_no,
            transaction_id: data.transaction_id,
            payment_status: data.payment_status,
            amount: data.amount,
            id: orderId,
        });

        if (data.grant_type === "failed") {
            return { SUCCESS: true, MESSAGE: "Marked as failed" };
        }

        const cart = await commonObj.getData("cart", {
            where: [{ key: "emp_id", operator: "is", value: data.emp_id }],
        });

        if (!cart.SUCCESS || cart.MESSAGE.length === 0) {
            return { SUCCESS: false, MESSAGE: "Cart not found" };
        }

        const employeeRes = await commonObj.getData("employee", {
            where: [{ key: "id", operator: "is", value: data.emp_id }],
        });

        const products = await commonObj.getData("products", {});
        const settings = await commonObj.getData("settings", {});
        const cmbProd = await commonObj.getData("combo_product", {
            where: [{ key: "order_id", operator: "is", value: orderId }],
        });

        const invoiceItems = await InvoiceService.prepareInvoiceItems(cart.MESSAGE, products.MESSAGE, commonObj);
        await InvoiceService.updateStockForComboProducts(cmbProd.MESSAGE, products.MESSAGE, commonObj);

        const employee = employeeRes.MESSAGE;
        const companies = await commonObj.getData("companies", {
            where: [{ key: "id", operator: "is", value: employee.company }],
        });

        await InvoiceService.generateInvoice({
            employee,
            items: invoiceItems,
            comboProducts: cmbProd.MESSAGE,
            data,
            settings: settings.MESSAGE[0],
            orderId,
            company: companies.MESSAGE,
        });
        
        // CHNAGE EMAIL SERVICE 
        // const emailService = new EmailService(settings.email_api, {});
        // await emailService.sendInvoiceEmail(employee, settings.MESSAGE[0], orderId);

        await commonObj.setDelete("cart", { emp_id: data.emp_id });

        return { SUCCESS: true, MESSAGE: "Order confirmed" };
    }
};
