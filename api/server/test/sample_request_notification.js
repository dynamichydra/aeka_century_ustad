const template = `
Hello %#%receiver Name%#%, 

A new sample request has been submitted by %#%User Name%#% for Lead no: %#%Lead No%#%. 
The detail Specification are as follow:

%#%loop%#%
%#%Product Name%#% (%#%Product SKU%#%) : %#%Product Qnt%#%
%#%loop_end%#%

Thanks
`;


function generateHtmlFromText(data) {
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

module.exports = generateHtmlFromText;
