/**
 * Local-only script to seed the admin document in the Firestore Emulator.
 *
 * SAFETY GUARDS:
 * 1. Hardcodes FIRESTORE_EMULATOR_HOST to 127.0.0.1:8080.
 * 2. Explicitly verifies that the environment targets localhost/127.0.0.1.
 * 3. Uses @firebase/rules-unit-testing to bypass client rules in the local emulator only.
 * 4. Does NOT include any production credentials, tokens, or API keys.
 * 5. Can never connect to production Firestore.
 */

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';

const PROJECT_ID = 'bashalagbe-f9595';
const EMULATOR_HOST = '127.0.0.1';
const EMULATOR_PORT = 8080;
const ADMIN_UID = '5xLg1yi5McU1tt6SxZin1cSpuXF3';

async function main() {
  const hostString = `${EMULATOR_HOST}:${EMULATOR_PORT}`;
  process.env.FIRESTORE_EMULATOR_HOST = hostString;

  if (
    !process.env.FIRESTORE_EMULATOR_HOST.startsWith('127.0.0.1:') &&
    !process.env.FIRESTORE_EMULATOR_HOST.startsWith('localhost:')
  ) {
    throw new Error('ABORTED: FIRESTORE_EMULATOR_HOST must point to localhost or 127.0.0.1');
  }

  console.log(`Connecting to local Firestore emulator at ${hostString}...`);

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: EMULATOR_HOST,
      port: EMULATOR_PORT,
    },
  });

  try {
    // withSecurityRulesDisabled grants admin/bypass context in the local emulator
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const adminDocRef = doc(db, 'admins', ADMIN_UID);

      await setDoc(adminDocRef, {
        role: 'admin',
        createdAt: serverTimestamp(),
      });

      console.log('Admin document successfully written to local emulator.');

      // Verification read
      const snapshot = await getDoc(adminDocRef);
      if (snapshot.exists()) {
        const data = snapshot.data();
        console.log('\nVerification:');
        console.log(`- Path:       /admins/${ADMIN_UID}`);
        console.log(`- Exists:     ${snapshot.exists()}`);
        console.log(`- Role:       ${data?.role}`);
        console.log(`- CreatedAt:  ${data?.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate().toISOString() : data.createdAt) : 'Timestamp set'}`);
        console.log('\nSuccess! The account is now registered as an admin in your local Firestore emulator.');
      } else {
        console.error('Verification failed: Document does not exist after write.');
      }
    });
  } catch (err) {
    console.error('Failed to seed admin document:', err.message || err);
    console.error('\nPlease ensure the Firestore emulator is running on port 8080:');
    console.error('  firebase emulators:start --only firestore');
    process.exit(1);
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});

