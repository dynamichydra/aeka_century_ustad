
exports.config = {ip:null, port:null};
exports.init = function(){
    const cors = require('cors');
    const express = require('express')

    const expressApp = express();
    
    expressApp.use(cors({
        origin: '*'
    }));
    expressApp.use(express.urlencoded({extended: true, limit:'100mb'}));
    expressApp.use(express.json({limit:'100mb'}));

    expressApp.use(function(req, res, next) {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      res.setHeader('Access-Control-Allow-Credentials', true);
      next();
  });

    expressApp.use('/', express.static('app'));

    expressApp.get('/info', (req, res) => {
        let info = {
            ip: this.ip,
            port: this.port
        };
        res.setHeader('Content-Type', 'application/json');
         res.send(JSON.stringify(info));
    })

    expressApp.listen(this.port, '0.0.0.0', () => {
        console.log(`Manager app listening on port ${this.ip}:${this.port}`)
    })


    exports.app = expressApp;
}

exports.setPort = function(port){
    this.port = port
}


exports.setIp = function(ip){
    this.ip = ip
}