#!/usr/bin/env node

import {
  SYSTEM_VERSION,
  bootSequence,
  createSystemProfile,
  formatStatus
} from './nodeos.js';

const customHostname = process.argv[2] || 'nodeos';
const profile = createSystemProfile({
  hostname: customHostname,
  user: process.env.USER || 'root',
  mode: 'secure',
  network: 'private'
});

console.log(`NodeOS ${SYSTEM_VERSION}`);
console.log('Boot sequence:');
console.log(bootSequence().join(' -> '));
console.log('');
console.log(formatStatus(profile));
