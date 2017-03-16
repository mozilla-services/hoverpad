#!/usr/bin/env node

const { writeFileSync } = require('fs');
const PACKAGE_JSON = require('../manifest.json');

PACKAGE_JSON['applications'] = undefined;
const str = JSON.stringify(PACKAGE_JSON, null, 2) + '\n';
writeFileSync(require.resolve('../www/manifest.json'), str);
