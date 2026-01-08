const fs = require("fs");
const PDFDocument = require("pdfkit");

function createInvoice(invoice, path) {
    let doc = new PDFDocument({ size: "A4", margin: 50 });

    generateHeader(doc, invoice.settings);
    generateCustomerInformation(doc, invoice);
    generateInvoiceTable(doc, invoice.items, invoice.combo);
    generateFooter(doc,invoice.settings);

    doc.end();
    doc.pipe(fs.createWriteStream(path));
}

function generateHeader(doc, settings) {
    doc
        .image("invoice/logo.png", 50, 45, { width: 50 })
        .fillColor("#444444")
        .fontSize(10)
        .text(settings.invoice_company, 200, 50, { align: "right" })
        .text(settings.invoice_address, 200, 65, { align: "right" })
        .text(settings.invoice_address_more, 200, 80, { align: "right" })
        .moveDown();
}

function generateCustomerInformation(doc, invoice) {
    doc
        .fillColor("#444444")
        .fontSize(20)
        .text("Order summary", 50, 110);

    generateHr(doc, 135);

    const posY = 145;
    
    doc
        .fontSize(10)
        .text(invoice.company, 50, posY )
        .text("Employee Name:", 50, posY+15)
        .text(invoice.emp_name, 140, posY+15)
        .text("Email ID:", 50, posY + 30)
        .text(invoice.emp_email, 140, posY + 30)
        
        // .text(invoice.emp_phone, 140, posY + 30)

        .text("Order Number:", 320, posY)
        .font("Helvetica-Bold")
        .text(invoice.order_no, 410, posY)
        .font("Helvetica")
        .text("Transaction ID:", 320, posY + 15)
        .text(invoice.transaction_id, 410, posY + 15)
        .text("Order Date:", 320, posY+30)
        .text(invoice.date, 410, posY+30)
        .moveDown();

    generateHr(doc, 195);
}

function generateInvoiceTable(doc, items, combo) {
    let posY = 250;

    doc.font("Helvetica-Bold");
    generateTableRow(doc,posY,"Item","Description","Quantity","Price");
    generateHr(doc, posY + 20);
    doc.font("Helvetica");
    let gst = 0;
    let prodPrice = 0;

    for (let i = 0; i < items.length; i++) {
        const item = items[i];
        posY +=30;
        let pPrice = ((items[i].amount * items[i].quantity)/(100+parseFloat(items[i].gst)))*100;
        let pGst = ((items[i].amount * items[i].quantity)/(100+parseFloat(items[i].gst)))* items[i].gst;
        gst += pGst;
        prodPrice += pPrice;
        doc.fontSize(10);
        generateTableRow(
            doc,
            posY,
            item.item,
            item.description,
            item.quantity,
            (pPrice).toFixed(2)
        );
        let cProd = combo.filter(e=> e.base_product == item.id);
        if(cProd && cProd.length>0){
            for(const free of cProd){
                doc.fontSize(8);
                posY += 15;
                generateTableRow(
                    doc,
                    posY,
                    free.mat_code,
                    free.sku,
                    free.quantity,
                    "0.00"
                );
            }
        }
        generateHr(doc, posY + 20);
    }
    doc.fontSize(10);
    posY +=30;
    generateTableRow(
        doc,
        posY,
        "",
        "",
        "Subtotal",
        (prodPrice).toFixed(2)
    );
    posY +=20;
    generateTableRow(
        doc,
        posY,
        "",
        "",
        "GST",
        gst.toFixed(2)
    );
    posY +=25;
    doc.font("Helvetica-Bold");
    generateTableRow(
        doc,
        posY,
        "",
        "",
        "Total",
        (prodPrice+gst).toFixed(2)
    );
    doc.font("Helvetica");
}

function generateFooter(doc,settings) {
    doc
        .fontSize(10)
        .text(
            settings.invoice_footer,
            50,
            780,
            { align: "center", width: 500 }
        );
}

function generateTableRow(
    doc,
    y,
    item,
    description,
    quantity,
    lineTotal
) {
    doc.text(item, 50, y)
        .text(description, 150, y)
        .text(quantity, 370, y, { width: 90, align: "right" })
        .text(lineTotal, 0, y, { align: "right" });
}

function generateHr(doc, y) {
    doc
        .strokeColor("#aaaaaa")
        .lineWidth(1)
        .moveTo(50, y)
        .lineTo(550, y)
        .stroke();
}

module.exports = {
    createInvoice
};