'use strict';

module.exports = {
  ...require('./authValidators'),
  ...require('./userValidators'),
  ...require('./chatValidators'),
  ...require('./groupValidators'),
  ...require('./callValidators'),
};
