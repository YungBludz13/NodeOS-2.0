export const SYSTEM_VERSION = '2.0.0';

export function bootSequence() {
  return [
    'kernel init',
    'device discovery',
    'filesystem mount',
    'network bootstrap',
    'service registry',
    'secure login'
  ];
}

export function createSystemProfile(options = {}) {
  const profile = {
    hostname: 'nodeos',
    user: 'root',
    mode: 'secure',
    network: 'private',
    services: ['kernel', 'network', 'logging', 'update'],
    ...options
  };

  return {
    ...profile,
    version: SYSTEM_VERSION,
    status: 'ready'
  };
}

export function validateProfile(profile) {
  if (!profile || typeof profile !== 'object') {
    return { valid: false, error: 'Profile must be an object.' };
  }

  const required = ['hostname', 'user', 'mode', 'network'];
  for (const key of required) {
    if (!profile[key]) {
      return { valid: false, error: `Missing required field: ${key}` };
    }
  }

  return { valid: true, profile };
}

export function formatStatus(profile) {
  const validation = validateProfile(profile);
  if (!validation.valid) {
    return `System status: invalid profile (${validation.error})`;
  }

  const { hostname, user, mode, network, version, status } = profile;
  return [
    `Hostname: ${hostname}`,
    `User: ${user}`,
    `Mode: ${mode}`,
    `Network: ${network}`,
    `Version: ${version}`,
    `Status: ${status}`
  ].join('\n');
}
