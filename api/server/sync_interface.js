var bodyParser = require('body-parser');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const config = require('config');

var APP_SyncInterface = function (executor, express) {
  let _ = this;
  _.executor = executor;
  _.app = express;
  _.app.use(bodyParser.json());
  _.app.use(bodyParser.urlencoded({ extended: true }));

  _.storage = multer.diskStorage({
    destination: function (req, file, cb) {
      cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
      const uniqueFileName = Date.now() + '-' + file.originalname;
      cb(null, uniqueFileName);
    }
  });
  _.upload = multer({ storage: _.storage, limits: { fileSize: 50 * 1024 * 1024 } });

  _.storagePImage = multer.memoryStorage();
  _.uploadImage = multer({ storage: _.storagePImage });
}


APP_SyncInterface.prototype.start = function () {
  let _ = this;

  const checkAuthToken = (req, res, next) => {
    let obj = req.body;
    if (req.method === 'OPTIONS') {
      res.status(405).send({ SUCCESS: false, MESSAGE: 'Method Not Allowed' });
      return;
    }
    const pathAllow = ['/ldaptest', '/register', '/download-invoice', '/download-sample', '/upload_pimage', 'sync'];
    if (obj.TYPE === 'auth' && (obj.DATA.grant_type === 'register' ||  obj.DATA.grant_type === 'password' || obj.DATA.grant_type === 'reset_password' || obj.DATA.grant_type === 'set_password') ||
        pathAllow.some(e => req.path.includes(e))) {
      return next();
    }

    const token = req.header('Authorization');

    if (!token) {
      return res.status(401).json({ SUCCESS: false, MESSAGE: 'Access token missing' });
    }

    _.executor.executeTask(null, 'auth', null, {
      token: token.replace('Bearer ', ''),
      grant_type: 'validateToken'
    }).then(function (validation) {
      if (validation.SUCCESS) {
        req.user = validation.MESSAGE.userId;
        next();
      } else {
        res.status(403).json({ SUCCESS: false, MESSAGE: 'Invalid Access' });
      }
    });
  };

  _.app.use(checkAuthToken);

  _.app.post('/upload_image', _.uploadImage.single('image'), async (req, res) => {
    if (!req.file) {
      return res.json({ SUCCESS: false, MESSAGE: 'No file uploaded.' });
    }

    const obj = req.body;
    let newFileName = null;
    let outputPath = null;
    let upPath = config.get("upload_path");
    if (obj.type == 'product') {
      upPath = upPath.product;
      newFileName = `${obj.id}.png`;
      outputPath = path.join(__dirname, upPath.path, newFileName);
    }

    if (outputPath) {
      try {
        await sharp(req.file.buffer).png().toFile(outputPath);
        res.json({ SUCCESS: true, MESSAGE: upPath.path_actual + newFileName });
      } catch (error) {
        res.json({ SUCCESS: false, MESSAGE: 'Error processing image.' });
      }
    } else {
      res.json({ SUCCESS: false, MESSAGE: 'Error processing image.' });
    }

  });


  _.app.get('/download-invoice/:invoiceId', (req, res) => {
    const invoiceId = req.params.invoiceId;

    const invoicePath = path.join(__dirname, '../invoice', `${invoiceId}.pdf`);
    console.log(invoicePath)

    res.download(invoicePath, `${invoiceId}.pdf`, (err) => {
      if (err) {
        console.error('Error downloading the invoice:', err);
        res.status(500).send('Could not download the invoice');
      }
    });
  });

  _.app.get('/download-sample/:name', (req, res) => {
    const name = req.params.name;
    const fPath = path.join(__dirname, '../sample', `${name}`);
    res.download(fPath, `${name}`, (err) => {
      if (err) {
        console.error('Error downloading the invoice:', err);
        res.status(500).send('Could not download the invoice');
      }
    });
  });


  _.app.get('/ldaptest', async (req, res) => {
    const ldap = require("ldapjs");
    const client = ldap.createClient({
      url: "ldap://172.22.1.72"
    });
    try {
      client.bind('APPBGUSER', '32wedsf#@$', async (err) => {
        if (err) {
          rconsole.log(err)
        } else {
          console.log('ok')
        }
      });
      // return true;
    } catch (error) {
      console.log(1)
      console.log(error)
      // return false;
    } finally {
      client.unbind();
    }
  });

  _.app.post('/sync', async function (req, res) {
    console.log('Sync Request:');
    const baseModule = require('./service/sync/base');
    try {
        const output = await baseModule.lib.init(req.body);
        console.log('Sync Output:');
        console.log(output);
        res.json(output);
    } catch (ex) {
      res.json(ex);
    }

  });

  _.app.post('/api', function (req, res) {
    let obj = req.body;
    _.executor.executeTask(obj.SOURCE, obj.TYPE, obj.TASK, obj.DATA).then(function (result) {
      if (result) {
        res.json(result);
      } else {
        res.json({ SUCCESS: false, MESSAGE: 'Invalid request' });
      }
    }).catch(function (error) {
      console.log(error);
      res.json(error);
    });

  });
}

module.exports = APP_SyncInterface;