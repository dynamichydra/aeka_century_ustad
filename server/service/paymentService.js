const RazorpayService = require("./providers/RazorpayService");
const CCAvenueService = require("./providers/CCAvenueService");

class PaymentService {
    constructor(config = {}) {
        this.method = config.payment_type.toLowerCase();
                
        if (this.method === "razorpay") {
            this.provider = new RazorpayService(config);
        } else if (this.method === "ccavenue") {
            this.provider = new CCAvenueService(config);;
        } else {
            throw new Error("Unsupported payment method");
        }
    }

    async initiate(commonObj, data) {
        return this.provider.initiate(commonObj, data);
    }

    verify(data) {
        return this.provider.verify(data);
    }
}

module.exports = PaymentService;
