import test from 'node:test';
import assert from 'node:assert/strict';

import {
  SYSTEM_VERSION,
  bootSequence,
  createSystemProfile,
  formatStatus,
  validateProfile
} from '../src/nodeos.js';

test('system version is set', () => {
  assert.equal(SYSTEM_VERSION, '2.0.0');
});

test('boot sequence includes the expected stages', () => {
  const steps = bootSequence();
  assert.deepEqual(steps[0], 'kernel init');
  assert.equal(steps.length, 6);
});

test('system profiles are created with defaults', () => {
  const profile = createSystemProfile();
  assert.equal(profile.hostname, 'nodeos');
  assert.equal(profile.user, 'root');
  assert.equal(profile.mode, 'secure');
  assert.equal(profile.version, SYSTEM_VERSION);
});

test('profile validation rejects missing fields', () => {
  const result = validateProfile({ hostname: 'nodeos' });
  assert.equal(result.valid, false);
  assert.match(result.error, /Missing required field/);
});

test('status format renders key fields', () => {
  const profile = createSystemProfile({ hostname: 'demo-host' });
  const formatted = formatStatus(profile);
  assert.match(formatted, /Hostname: demo-host/);
  assert.match(formatted, /Version: 2.0.0/);
});
