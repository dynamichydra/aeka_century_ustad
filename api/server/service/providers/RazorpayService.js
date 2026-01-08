const Razorpay = require("razorpay");
const crypto = require("crypto");
const config = require("config");


class RazorpayService {
    constructor(configObj = {}) {
        this.razorpay = new Razorpay({
            key_id: configObj.razorpay_key_id,
            key_secret: configObj.razorpay_key_secret,
        });
        this.key_secret = configObj.razorpay_key_secret ;
    }

    async initiate(commonObj,data) {
        const options = {
            amount: Number(data.amount * 100),
            currency: "INR",
        };

        try {
            const order = await this.razorpay.orders.create(options);
            return order;
        } catch (err) {
            console.error("Razorpay order creation failed:", err);
            throw err;
        }
    }

    verify({ razorpay_order_id, razorpay_payment_id, razorpay_signature }) {
        const body = razorpay_order_id + "|" + razorpay_payment_id;
        const expectedSignature = crypto
            .createHmac("sha256", this.key_secret)
            .update(body)
            .digest("hex");

        return expectedSignature === razorpay_signature;
    }
}

module.exports = RazorpayService;
