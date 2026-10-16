import assert from 'node:assert/strict';

// Emulator Hub endpoints behind @firebase/rules-unit-testing withFunctionTriggersDisabled.
// While disabled, the Functions Emulator acknowledges background events with 204 and
// never invokes the function, so a write in this window is a genuinely missed trigger.
const disablePath = '/functions/disableBackgroundTriggers';
const enablePath = '/functions/enableBackgroundTriggers';

export async function withFunctionTriggersDisabled<T>(body: () => Promise<T>): Promise<T> {
  await putHub(disablePath);
  try {
    return await body();
  } finally {
    await putHub(enablePath);
  }
}

async function putHub(path: string): Promise<void> {
  const hub = process.env.FIREBASE_EMULATOR_HUB ?? '';
  assert.match(hub, /^(127\.0\.0\.1|localhost):\d+$/u);
  const response = await fetch(`http://${hub}${path}`, { method: 'PUT' });
  assert.equal(response.status, 200, `${path} -> ${response.status}`);
}
