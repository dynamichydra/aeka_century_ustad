var request = require('request').defaults({ encoding: null });

global.imgeUrlToBase64 = function (url,cb) {
    request.get(url, function (error, response, body) {
        if (!error && response.statusCode == 200) {
            data = "data:" + response.headers["content-type"] + ";base64," + Buffer.from(body).toString('base64');
            return cb(data);
        }
    });
}

global.findValue = function (data,key,val) {
  if(!data || data.length ==0) return null;
  return data.find(function(value) {
    if(value)return value[key] == val;
    else return null;
  });
}
global.findValueParticipants = function (data,id) {
  var field = data.find(function(value) {
    return value.FIELD_ID == id;
  });

  if (!field) {
    field = {
      VALUE: null
    };
  }
  return field;
}