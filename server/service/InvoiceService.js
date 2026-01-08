const { createInvoice } = require("../modules/mysql/createInvoice");
const moment = require("moment");

const InvoiceService = {
    async prepareInvoiceItems(cart, products, commonObj) {
        const items = [];

        for (let item of cart) {
            const product = products.find(p => p.id === item.product_id);
            if (product) {
                items.push({
                    id: product.id,
                    item: product.mat_code,
                    description: product.name,
                    quantity: item.quantity,
                    amount: product.offer_price,
                    mrp: product.mrp,
                    gst: product.gst,
                });

                await commonObj.setData("products", {
                    id: product.id,
                    stock: parseFloat(product.stock) - parseFloat(item.quantity),
                });
            }
        }

        return items;
    },

    async updateStockForComboProducts(comboItems, products, commonObj) {
        for (let item of comboItems) {
            const prod = products.find(p => p.id === item.product_id);
            if (prod) {
                await commonObj.setData("products", {
                    id: prod.id,
                    stock: parseFloat(prod.stock) - parseFloat(item.quantity),
                });
            }
        }
    },

    async generateInvoice({ employee, items, data, settings, orderId, company, comboProducts }) {
        const invoiceData = {
            settings,
            items,
            amount: data.amount,
            date: moment(data.date).format("DD-MM-YYYY"),
            transaction_id: data.transaction_id,
            order_no: data.order_no,
            emp_name: employee.name,
            emp_email: employee.email,
            emp_phone: employee.phone,
            company: company.name,
            combo: comboProducts,
        };

        await createInvoice(invoiceData, `invoice/${orderId}-${employee.id}.pdf`);
    }
};

module.exports = InvoiceService;
