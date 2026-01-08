const nodemailer = require('nodemailer');

class EmailService {
  constructor(type,config) {
    this.type = type;
    this.config = config;
    
    if (type === 'smtp') {
      this.transporter = nodemailer.createTransport({
        host: config.smtp_host,
        port: config.smtp_port,
        secure: config.smtp_port === 465,
        auth: {
          user: config.smtp_user,
          pass: config.smtp_pwd,
        },
      });
    } else if (type === 'sendgrid') {
      this.transporter = nodemailer.createTransport({
        service:'SendGrid',
        auth: {
          user: 'apikey', // SendGrid requires literal "apikey" as username
          pass: config.sendgrid,
        },
      });
    } else {
      throw new Error(`Unsupported email service type: ${type}`);
    }
  }

  async sendEmail({ from, to, subject, text, html, attachments = [] }) {
    try {
      const info = await this.transporter.sendMail({
        from,
        to,
        subject,
        text,
        html,
        attachments: attachments.map(att => ({
          filename: att.filename,
          path: att.path,
          contentType: att.contentType,
        })),
      });
      console.log('Email sent via SMTP:', info.messageId);
      return { SUCCESS:true,MESSAGE:info};
    } catch (err) {
      console.error('Error sending email via SMTP:', err);
      return { SUCCESS: false, MESSAGE: err };
    }
  }
}

module.exports = EmailService;