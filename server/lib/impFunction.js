const moment = require('moment');

const impFunction = function () {
  
}

impFunction.prototype.findValueDate = function(data,key,val){
  if(!data || data.length ==0) return null;
  return data.find(function(value) {
    if(value)return moment(value[key]).format('YYYY-MM-DD HH:mm:ss') == val;
    else return null;
  });
}
impFunction.prototype.findValue = function(data,key,val){
  if(!data || data.length ==0) return null;
  return data.find(function(value) {
    if(value)return value[key] == val;
    else return null;
  });
}

impFunction.prototype.getCurrentDate = function(){
  let today = new Date();
  let dd = String(today.getDate()).padStart(2, '0');
  let mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
  let yyyy = today.getFullYear();

  return yyyy + '-' + mm + '-' + dd ;
}

impFunction.prototype.generateNUniqueRandomNumbers = function (n,arrayToExclude,f,t) {
  if (n <= 0) {
    throw new Error('Invalid value for n. n must be greater than 0.');
  }

  const min = f??100;
  const max = t??900;
  const randomNumbers = [];

  while (randomNumbers.length < n) {
    let randomNumber;
    do {
      randomNumber = Math.floor(Math.random() * (max - min + 1)) + min;
    } while (arrayToExclude.includes(randomNumber));

    randomNumbers.push(randomNumber);
  }

  return randomNumbers;
}

impFunction.prototype.isValidIndianPhoneNumber = function(number) {
  return /^[6-9]\d{9}$/.test(number);
}

impFunction.prototype.isValidEmailStrict = function(email) {
  return /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email);
}

module.exports = new impFunction(); 