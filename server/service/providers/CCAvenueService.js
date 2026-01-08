const moment = require("moment");
const config = require("config");
const nodeCCAvenue = require("node-ccavenue");

class CCAvenueService {
    constructor(configObj = {}) {
        this.ccav = new nodeCCAvenue.Configure({
            merchant_id: configObj.ccavenue_merchant_id,
            working_key: configObj.ccavenue_working_key,
        });

        this.accessCode = configObj.ccavenue_access_code;
        this.apiUrl = configObj.api_url;
    }
    async initiate(commonObj, data) {

        //  NEED FOR REAL PROJECT NOT TEST OR DUMMY

        // const settings = await commonObj.getData("settings", {});
        // const windowEnd = moment(settings.MESSAGE[0].window_close).utc();
        // const currentDate = moment().utc();

        // if (windowEnd.isBefore(currentDate)) {
        //     throw new Error("Window is closed");
        // }

        // const cart = await commonObj.getData("cart", {
        //     where: [{ key: "emp_id", operator: "is", value: data.emp_id }],
        // });

        // if (cart.MESSAGE.length === 0) throw new Error("Cart is empty");

        // const products = await commonObj.getData("products", {});
        // let prodPrice = 0;

        // for (let item of cart.MESSAGE) {
        //     const prod = products.MESSAGE.find((p) => p.id === item.product_id);
        //     if (prod) {
        //         prodPrice += parseFloat(prod.offer_price) * item.quantity;
        //     }
        // }

        // if (parseFloat(prodPrice.toFixed(2)) !== parseFloat(data.amount.toFixed(2))) {
        //     throw new Error("Invalid amount");
        // }

        const payload = {
            order_id: data.order_id,
            amount: data.amount,
            currency: "INR",
            merchant_param1: data.emp_id,
            redirect_url: encodeURIComponent(`${this.apiUrl}ccavenue/payment-response`),
            cancel_url: encodeURIComponent(`${this.apiUrl}ccavenue/cancel`),
            language: "EN",
        };

        const encryptedData = this.ccav.getEncryptedOrder(payload);

        return `https://secure.ccavenue.com/transaction/transaction.do?command=initiateTransaction&encRequest=${encryptedData}&access_code=${this.accessCode}`;
    }

    static verify() {
        return true;
    }
}

module.exports = CCAvenueService;
