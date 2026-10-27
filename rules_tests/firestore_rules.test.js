import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, it, beforeAll, afterAll, beforeEach, expect } from 'vitest';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
  serverTimestamp,
  Timestamp,
  collection,
  query,
  where,
  getDocs,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-bashalagbe';
const EMULATOR_HOST = '127.0.0.1';
const EMULATOR_PORT = 8080;

let testEnv;

beforeAll(async () => {
  process.env.FIRESTORE_EMULATOR_HOST = `${EMULATOR_HOST}:${EMULATOR_PORT}`;
  const rulesPath = resolve('web/firestore.rules');
  const rules = readFileSync(rulesPath, 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: EMULATOR_HOST,
      port: EMULATOR_PORT,
      rules,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Helper functions for seeding data ONLY (Requirement 6: withSecurityRulesDisabled used strictly for setup)
async function seedUser(userId, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', userId), {
      displayName: 'Sample User',
      email: `${userId}@example.com`,
      createdAt: Timestamp.now(),
      ...data,
    });
  });
}

async function seedProperty(propertyId, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'properties', propertyId), {
      ownerId: 'landlord_1',
      status: 'approved',
      title: 'Dhanmondi Cozy 2BHK',
      area: 'Dhanmondi',
      propertyType: 'Family',
      division: 'Dhaka',
      rentPerMonth: 25000,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...data,
    });
  });
}

async function seedRentalRequest(requestId, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'rental_requests', requestId), {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'pending',
      tenantName: 'Karim Ahmed',
      tenantPhone: '01700000000',
      preferredMoveIn: '2026-11-01',
      tenantEmail: 'tenant@example.com',
      message: 'Looking forward to viewing',
      propertyTitle: 'Dhanmondi Cozy 2BHK',
      propertyArea: 'Dhanmondi',
      rentPerMonth: 25000,
      propertyPhotoUrl: 'https://example.com/photo.jpg',
      landlordNote: null,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...data,
    });
  });
}

async function seedContactInfo(propertyId, docId = 'details', data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'properties', propertyId, 'contact_info', docId), {
      ownerId: 'landlord_1',
      propertyId: propertyId,
      phone: '01712345678',
      whatsapp: '01712345678',
      email: 'landlord@example.com',
      otherTitle: 'Messenger',
      otherLink: 'https://m.me/landlord',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...data,
    });
  });
}

async function seedAdmin(adminId, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'admins', adminId), {
      assignedAt: Timestamp.now(),
      ...data,
    });
  });
}

async function seedConversation(conversationId, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'conversations', conversationId), {
      requestId: conversationId,
      propertyId: 'prop_chat_1',
      propertyTitle: 'Chat Flat',
      ownerId: 'landlord_1',
      tenantId: 'tenant_1',
      tenantName: 'Tenant One',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...data,
    });
  });
}

// =============================================================================
// 1. Users & Favourites Collection (/users/{userId})
// =============================================================================
describe('Firestore Security Rules: Users Collection (/users/{userId})', () => {
  it('allows authenticated user to read their own profile', async () => {
    await seedUser('user_alice');
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertSucceeds(getDoc(doc(db, 'users', 'user_alice')));
  });

  it('allows authenticated user to write their own profile with permitted fields', async () => {
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users', 'user_alice'), {
        displayName: 'Alice In Wonderland',
        email: 'alice@example.com',
        phone: '01811111111',
      })
    );
  });

  it('allows user to manage favouritePropertyIds and updatedAt (Flutter favourites flow)', async () => {
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertSucceeds(
      setDoc(
        doc(db, 'users', 'user_alice'),
        {
          favouritePropertyIds: ['prop_1', 'prop_2'],
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
    );
  });

  it('denies authenticated user from reading another user profile', async () => {
    await seedUser('user_bob');
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertFails(getDoc(doc(db, 'users', 'user_bob')));
  });

  it('denies authenticated user from writing another user profile', async () => {
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users', 'user_bob'), {
        displayName: 'Hacked Bob',
      })
    );
  });

  it('denies user from self-assigning authorization-sensitive role field', async () => {
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users', 'user_alice'), {
        displayName: 'Alice',
        email: 'alice@example.com',
        role: 'admin',
      })
    );
  });

  it('denies user from self-assigning authorization-sensitive isAdmin flag', async () => {
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users', 'user_alice'), {
        displayName: 'Alice',
        email: 'alice@example.com',
        isAdmin: true,
      })
    );
  });

  it('denies user from adding unexpected arbitrary fields outside profile schema', async () => {
    const db = testEnv.authenticatedContext('user_alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users', 'user_alice'), {
        displayName: 'Alice',
        secretPasscode: '12345',
      })
    );
  });

  it('denies unauthenticated user from reading or writing user profiles', async () => {
    await seedUser('user_alice');
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users', 'user_alice')));
    await assertFails(
      setDoc(doc(db, 'users', 'user_alice'), {
        displayName: 'Anonymous Hacker',
      })
    );
  });
});

// =============================================================================
// 2. Property Listings (/properties/{propertyId})
// =============================================================================
describe('Firestore Security Rules: Property Listings (/properties/{propertyId})', () => {
  it('allows public/unauthenticated read of approved property listings', async () => {
    await seedProperty('prop_approved', { status: 'approved' });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, 'properties', 'prop_approved')));
  });

  it('denies public/unauthenticated read of pending property listings', async () => {
    await seedProperty('prop_pending', { status: 'pending' });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'properties', 'prop_pending')));
  });

  it('allows property owner to read their own pending property listing', async () => {
    await seedProperty('prop_pending', {
      ownerId: 'landlord_1',
      status: 'pending',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(getDoc(doc(db, 'properties', 'prop_pending')));
  });

  it('denies non-owner from reading another user pending property listing', async () => {
    await seedProperty('prop_pending', {
      ownerId: 'landlord_1',
      status: 'pending',
    });
    const db = testEnv.authenticatedContext('stranger_1').firestore();
    await assertFails(getDoc(doc(db, 'properties', 'prop_pending')));
  });

  it('allows landlord to create property listing with status pending and valid minimal fields', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'properties', 'new_prop_1'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows landlord to create property listing with complete real-world PostPropertyScreen payload', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'properties', 'real_world_prop'), {
        ownerId: 'landlord_1',
        status: 'pending',
        moderationNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        title: 'Spacious 3BHK Family Flat in Dhanmondi',
        description: 'Well-maintained rental home available for responsible tenants.',
        propertyType: 'Family',
        division: 'Dhaka',
        area: 'Dhanmondi',
        fullAddress: 'House 12, Road 5, Dhanmondi',
        landmark: 'Near central hub',
        rentPerMonth: 35000,
        depositAmount: 70000,
        sizeSqFt: 1450,
        floorLevel: '3rd Floor',
        bedrooms: 3,
        bathrooms: 3,
        balconies: 2,
        facilities: ['Lift', 'Generator', 'CCTV', 'Parking', 'Gas (Piped)'],
        availability: 'Available Now',
        availableNow: true,
        preferredTenant: 'Family only',
        utilityNotice: 'Utilities as per usage/prepaid meter.',
        nearbyHighlights: ['Dhanmondi Lake', 'Shopping Mall', 'Schools'],
        photos: [
          { label: 'Living Room', imageUrl: 'https://example.com/photo1.jpg' },
          { label: 'Master Bedroom', imageUrl: 'https://example.com/photo2.jpg' },
        ],
      })
    );
  });

  it('denies landlord from creating property with ownerEmail (privacy enforcement)', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_with_email'), {
        ownerId: 'landlord_1',
        ownerEmail: 'landlord@example.com',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with unexpected extra fields (whitelist enforcement)', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_extra'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        isAdmin: true, // Unexpected field
      })
    );
  });

  it('denies landlord from injecting moderationNote upon property creation', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_mod'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        moderationNote: 'Auto-approved by landlord', // Spoofed moderation note
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with empty title or empty area', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_empty_title'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: '', // Empty string
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );

    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_empty_area'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Valid Title',
        area: '', // Empty string
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with non-positive or non-integer rent', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    // Zero rent
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_zero_rent'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 0,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
    // Negative rent
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_neg_rent'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: -5000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property listing directly with status approved', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_approved'), {
        ownerId: 'landlord_1',
        status: 'approved',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with mismatched ownerId', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_mismatch'), {
        ownerId: 'landlord_2',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies unauthenticated user from creating property listing', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'new_prop_unauth'), {
        ownerId: 'any_user',
        status: 'pending',
        title: 'Mirpur Studio Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating approved property content without resetting status to pending (anti-bypass)', async () => {
    await seedProperty('prop_approved_edit', {
      ownerId: 'landlord_1',
      status: 'approved',
      rentPerMonth: 25000,
      title: 'Approved Flat In Mirpur',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    // Attempting to update content without resetting status to 'pending' must fail
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_approved_edit'), {
        title: 'Tampered Scam Title While Keeping Approved',
        rentPerMonth: 30000,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows owner to update property fields when resetting status to pending for re-moderation', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
      status: 'approved',
      rentPerMonth: 25000,
      title: 'Old Title',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'properties', 'prop_1'), {
        title: 'Updated Title',
        rentPerMonth: 27000,
        description: 'Updated property description',
        depositAmount: 50000,
        availableNow: true,
        status: 'pending',
        moderationNote: null,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows owner of rejected property to edit content and reset status to pending for re-review', async () => {
    await seedProperty('prop_rejected_reedit', {
      ownerId: 'landlord_1',
      status: 'rejected',
      rentPerMonth: 25000,
      title: 'Previously Rejected Flat',
      moderationNote: 'Photos were unclear',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'properties', 'prop_rejected_reedit'), {
        title: 'Improved Flat With Better Photos',
        status: 'pending',
        moderationNote: null,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating protected property fields: status directly to approved', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
      status: 'pending',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_1'), {
        status: 'approved',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating property status directly to rejected', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
      status: 'pending',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_1'), {
        status: 'rejected',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating protected property fields: ownerId', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_1'), {
        ownerId: 'landlord_2',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating protected property fields: createdAt', async () => {
    const initialCreatedAt = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
    await seedProperty('prop_created_at_test', {
      ownerId: 'landlord_1',
      createdAt: initialCreatedAt,
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_created_at_test'), {
        createdAt: Timestamp.now(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from tampering with moderationNote during update', async () => {
    await seedProperty('prop_mod_test', {
      ownerId: 'landlord_1',
      moderationNote: null,
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_mod_test'), {
        moderationNote: 'Verified and approved',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating unlisted keys outside whitelist', async () => {
    await seedProperty('prop_unlisted_test', {
      ownerId: 'landlord_1',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_unlisted_test'), {
        ownerEmail: 'tampered@example.com',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies owner from updating rent to non-positive or malformed value', async () => {
    await seedProperty('prop_rent_update_test', {
      ownerId: 'landlord_1',
      rentPerMonth: 25000,
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_rent_update_test'), {
        rentPerMonth: -1000,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies non-owner from updating owner property', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
    });
    const db = testEnv.authenticatedContext('stranger_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_1'), {
        title: 'Tampered Title',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows owner to delete their property listing', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(deleteDoc(doc(db, 'properties', 'prop_1')));
  });

  it('denies non-owner from deleting another user property listing', async () => {
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
    });
    const db = testEnv.authenticatedContext('stranger_1').firestore();
    await assertFails(deleteDoc(doc(db, 'properties', 'prop_1')));
  });

  // ---------------------------------------------------------------------------
  // Stage 1: Field Validation & Schema Limits
  // ---------------------------------------------------------------------------
  it('denies landlord from creating property with title shorter than 3 characters', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_short_title'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'AB',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with title longer than 150 characters', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_long_title'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'A'.repeat(151),
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with area shorter than 2 characters', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_short_area'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Valid Title Here',
        area: 'M',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 12000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with rent exceeding maximum ceiling (5,000,000)', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_excessive_rent'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Luxury Mansion',
        area: 'Gulshan',
        propertyType: 'Family',
        division: 'Dhaka',
        rentPerMonth: 5000001,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with description exceeding 2000 characters', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_long_desc'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Spacious Apartment',
        area: 'Dhanmondi',
        propertyType: 'Family',
        division: 'Dhaka',
        rentPerMonth: 30000,
        description: 'D'.repeat(2001),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with facilities exceeding 30 items', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    const tooManyFacilities = Array.from({ length: 31 }, (_, i) => `Facility ${i + 1}`);
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_too_many_fac'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Well Equipped Flat',
        area: 'Banani',
        propertyType: 'Family',
        division: 'Dhaka',
        rentPerMonth: 40000,
        facilities: tooManyFacilities,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with photos exceeding 10 items', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    const tooManyPhotos = Array.from({ length: 11 }, (_, i) => ({
      label: `Room ${i + 1}`,
      imageUrl: `https://example.com/p${i}.jpg`,
    }));
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_too_many_photos'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Photo Heavy Flat',
        area: 'Uttara',
        propertyType: 'Family',
        division: 'Dhaka',
        rentPerMonth: 25000,
        photos: tooManyPhotos,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating property with non-boolean availableNow', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_bad_bool'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Availability Test Flat',
        area: 'Mirpur',
        propertyType: 'Bachelor',
        division: 'Dhaka',
        rentPerMonth: 15000,
        availableNow: 'yes', // should be bool
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  // ---------------------------------------------------------------------------
  // Stage 1: Admin Authorization & Moderation
  // ---------------------------------------------------------------------------
  it('allows authorized admin in /admins to read admin document in /admins', async () => {
    await seedAdmin('admin_bob');
    const db = testEnv.authenticatedContext('admin_bob').firestore();
    await assertSucceeds(getDoc(doc(db, 'admins', 'admin_bob')));
  });

  it('denies non-admin authenticated user from reading admin document in /admins', async () => {
    await seedAdmin('admin_bob');
    const db = testEnv.authenticatedContext('any_user').firestore();
    await assertFails(getDoc(doc(db, 'admins', 'admin_bob')));
  });

  it('denies unauthenticated user from reading admin document in /admins', async () => {
    await seedAdmin('admin_bob');
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'admins', 'admin_bob')));
  });

  it('allows authorized admin in /admins to read another user pending property', async () => {
    await seedAdmin('admin_bob');
    await seedProperty('prop_pending_read', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Flat',
    });

    const dbAdmin = testEnv.authenticatedContext('admin_bob').firestore();
    await assertSucceeds(getDoc(doc(dbAdmin, 'properties', 'prop_pending_read')));
  });

  it('allows authorized admin in /admins to query pending properties across all owners', async () => {
    await seedAdmin('admin_bob');
    await seedProperty('prop_pending_1', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Flat 1',
    });
    await seedProperty('prop_pending_2', {
      ownerId: 'landlord_2',
      status: 'pending',
      title: 'Pending Flat 2',
    });

    const dbAdmin = testEnv.authenticatedContext('admin_bob').firestore();
    const q = query(collection(dbAdmin, 'properties'), where('status', '==', 'pending'));
    await assertSucceeds(getDocs(q));
  });

  it('denies non-admin from reading another user pending property', async () => {
    await seedProperty('prop_pending_private', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Private Flat',
    });

    const dbUser = testEnv.authenticatedContext('other_user').firestore();
    await assertFails(getDoc(doc(dbUser, 'properties', 'prop_pending_private')));
  });

  it('denies non-admin from querying pending properties across all owners', async () => {
    await seedProperty('prop_pending_other', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Flat',
    });

    const dbUser = testEnv.authenticatedContext('other_user').firestore();
    const q = query(collection(dbUser, 'properties'), where('status', '==', 'pending'));
    await assertFails(getDocs(q));
  });

  it('denies unauthenticated visitor from reading a pending property', async () => {
    await seedProperty('prop_pending_anon', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Flat Anon',
    });

    const dbAnon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(dbAnon, 'properties', 'prop_pending_anon')));
  });

  it('denies user from writing or creating an admin document in /admins (privilege escalation prevention)', async () => {
    const db = testEnv.authenticatedContext('user_attacker').firestore();
    await assertFails(
      setDoc(doc(db, 'admins', 'user_attacker'), {
        role: 'superadmin',
      })
    );
  });

  it('allows authorized admin in /admins to approve a pending property', async () => {
    await seedAdmin('admin_moderator');
    await seedProperty('prop_to_approve', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Flat For Moderation',
    });

    const dbAdmin = testEnv.authenticatedContext('admin_moderator').firestore();
    await assertSucceeds(
      updateDoc(doc(dbAdmin, 'properties', 'prop_to_approve'), {
        status: 'approved',
        moderationNote: 'Listing meets all community guidelines.',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows authorized admin in /admins to reject a pending property with moderation note', async () => {
    await seedAdmin('admin_moderator');
    await seedProperty('prop_to_reject', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Property Violating Guidelines',
    });

    const dbAdmin = testEnv.authenticatedContext('admin_moderator').firestore();
    await assertSucceeds(
      updateDoc(doc(dbAdmin, 'properties', 'prop_to_reject'), {
        status: 'rejected',
        moderationNote: 'Photo resolution too low. Please upload clear photos.',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies admin from altering property content (rent, title) during moderation', async () => {
    await seedAdmin('admin_moderator');
    await seedProperty('prop_admin_tamper', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Original Title',
      rentPerMonth: 20000,
    });

    const dbAdmin = testEnv.authenticatedContext('admin_moderator').firestore();
    await assertFails(
      updateDoc(doc(dbAdmin, 'properties', 'prop_admin_tamper'), {
        status: 'approved',
        rentPerMonth: 10000, // Admin must not alter property content!
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies admin from deleting another user property listing', async () => {
    await seedAdmin('admin_deleter');
    await seedProperty('prop_admin_delete', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Property Not Deletable By Admin',
    });

    const dbAdmin = testEnv.authenticatedContext('admin_deleter').firestore();
    await assertFails(deleteDoc(doc(dbAdmin, 'properties', 'prop_admin_delete')));
  });

  it('denies non-admin from approving a pending property', async () => {
    await seedProperty('prop_unauth_mod', {
      ownerId: 'landlord_1',
      status: 'pending',
      title: 'Pending Flat',
    });

    const dbNormal = testEnv.authenticatedContext('regular_user').firestore();
    await assertFails(
      updateDoc(doc(dbNormal, 'properties', 'prop_unauth_mod'), {
        status: 'approved',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('verifies public read of approved property does not expose ownerEmail on new listings', async () => {
    // Landlord creates a compliant property without ownerEmail
    const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      setDoc(doc(dbLandlord, 'properties', 'prop_no_email_test'), {
        ownerId: 'landlord_1',
        status: 'pending',
        title: 'Dhanmondi Lakefront Flat',
        area: 'Dhanmondi',
        propertyType: 'Family',
        division: 'Dhaka',
        rentPerMonth: 45000,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );

    // Admin approves the listing
    await seedAdmin('admin_mod');
    const dbAdmin = testEnv.authenticatedContext('admin_mod').firestore();
    await assertSucceeds(
      updateDoc(doc(dbAdmin, 'properties', 'prop_no_email_test'), {
        status: 'approved',
        updatedAt: serverTimestamp(),
      })
    );

    // Unauthenticated visitor reads approved listing
    const dbPublic = testEnv.unauthenticatedContext().firestore();
    const snap = await getDoc(doc(dbPublic, 'properties', 'prop_no_email_test'));
    expect(snap.exists()).toBe(true);
    expect(snap.data().ownerEmail).toBeUndefined();
  });
});

// =============================================================================
// 3. Rental Request Creation (/rental_requests/{requestId})
// =============================================================================
describe('Firestore Security Rules: Rental Request Creation (/rental_requests/{requestId})', () => {
  beforeEach(async () => {
    // Seed an approved property owned by landlord_1
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
      status: 'approved',
      title: 'Dhanmondi Cozy 2BHK',
      area: 'Dhanmondi',
    });
  });

  it('allows tenant to create valid pending request with deterministic ID for approved property', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertSucceeds(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'I want to rent this place',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/p.jpg',
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows tenant to create request with nullable propertyPhotoUrl (properties without photos)', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertSucceeds(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'No photo property request',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: null, // Valid null photo URL
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies tenant from creating request with unexpected extra fields (whitelist enforcement)', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Extra field injection',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        discountCode: '50_PERCENT_OFF', // Unexpected field
      })
    );
  });

  it('denies tenant from creating request with empty required strings', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    // Empty preferredMoveIn
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '', // Empty string
        tenantEmail: 'tenant@example.com',
        message: '',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );

    // Empty tenantPhone
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '', // Empty string
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: '',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from creating rental request to their own property (anti-self-rental)', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    const requestId = 'prop_1_landlord_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'landlord_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Landlord Renting Self',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'landlord@example.com',
        message: 'Self renting',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation with non-deterministic document ID', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const randomRequestId = 'random_doc_id_12345';
    await assertFails(
      setDoc(doc(db, 'rental_requests', randomRequestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Deterministic ID test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation if referenced property does not exist', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'non_existent_prop_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'non_existent_prop',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Missing property test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation if referenced property status is pending (not approved)', async () => {
    await seedProperty('prop_pending', {
      ownerId: 'landlord_1',
      status: 'pending',
    });
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_pending_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_pending',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Unapproved property test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation if payload ownerId does not match property ownerId', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'fake_landlord', // does not match landlord_1
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Mismatched owner test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation with initial status accepted or rejected', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'accepted',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Immediate accept test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation with invalid or non-integer rent', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Invalid rent test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: -500, // Negative number
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies request creation if initial landlordNote is provided', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const requestId = 'prop_1_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Note spoofing test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: 'Pre-approved note',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies unauthenticated user from creating rental request', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    const requestId = 'prop_1_tenant_1';
    await assertFails(
      setDoc(doc(db, 'rental_requests', requestId), {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
        propertyId: 'prop_1',
        status: 'pending',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-11-01',
        tenantEmail: 'tenant@example.com',
        message: 'Unauthenticated test',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        landlordNote: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// =============================================================================
// 4. Rental Request Read Operations
// =============================================================================
describe('Firestore Security Rules: Rental Request Read Operations', () => {
  beforeEach(async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'pending',
    });
  });

  it('allows requesting tenant to read their rental request', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertSucceeds(getDoc(doc(db, 'rental_requests', 'prop_1_tenant_1')));
  });

  it('allows property landlord to read rental request for their property', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(getDoc(doc(db, 'rental_requests', 'prop_1_tenant_1')));
  });

  it('denies third-party authenticated user from reading another rental request', async () => {
    const db = testEnv.authenticatedContext('stranger_1').firestore();
    await assertFails(getDoc(doc(db, 'rental_requests', 'prop_1_tenant_1')));
  });

  it('denies unauthenticated user from reading rental requests', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'rental_requests', 'prop_1_tenant_1')));
  });
});

// =============================================================================
// Rental Request Transaction Workflow & Read-Before-Write Regression Tests
// =============================================================================
describe('Firestore Security Rules: Rental Request Transaction Workflow & Read-Before-Write', () => {
  beforeEach(async () => {
    // Seed an approved property owned by landlord_1
    await seedProperty('prop_tx_1', {
      ownerId: 'landlord_1',
      status: 'approved',
      title: 'Gulshan Modern Suite',
      area: 'Gulshan',
    });
  });

  const validPayload = {
    propertyId: 'prop_tx_1',
    ownerId: 'landlord_1',
    tenantId: 'tenant_1',
    tenantEmail: 'tenant@example.com',
    tenantName: 'Karim Ahmed',
    tenantPhone: '01700000000',
    preferredMoveIn: '2026-11-01',
    message: 'Looking to rent',
    propertyTitle: 'Gulshan Modern Suite',
    propertyArea: 'Gulshan',
    rentPerMonth: 35000,
    propertyPhotoUrl: null,
    status: 'pending',
    landlordNote: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  it('allows tenant to check a nonexistent request without error (hasActiveRentalRequest pre-check)', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const docRef = doc(db, 'rental_requests', 'prop_tx_1_tenant_1');
    const snap = await assertSucceeds(getDoc(docRef));
    expect(snap.exists()).toBe(false);
  });

  it('denies unauthorized user from checking nonexistent request of another tenant', async () => {
    const dbStranger = testEnv.authenticatedContext('stranger_1').firestore();
    const docRef = doc(dbStranger, 'rental_requests', 'prop_tx_1_tenant_1');
    await assertFails(getDoc(docRef));
  });

  it('denies unauthenticated user from checking nonexistent rental requests', async () => {
    const dbUnauth = testEnv.unauthenticatedContext().firestore();
    const docRef = doc(dbUnauth, 'rental_requests', 'prop_tx_1_tenant_1');
    await assertFails(getDoc(docRef));
  });

  it('allows first rental request creation via real transaction (runTransaction with pre-read and write)', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    const docRef = doc(db, 'rental_requests', 'prop_tx_1_tenant_1');

    await assertSucceeds(
      runTransaction(db, async (transaction) => {
        const snapshot = await transaction.get(docRef);
        expect(snapshot.exists()).toBe(false);
        transaction.set(docRef, validPayload);
      })
    );

    // Verify document was genuinely created in Firestore
    const createdSnap = await assertSucceeds(getDoc(docRef));
    expect(createdSnap.exists()).toBe(true);
    expect(createdSnap.data().status).toBe('pending');
    expect(createdSnap.data().tenantId).toBe('tenant_1');
  });

  it('allows requesting tenant to read their newly created request', async () => {
    const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
    const docRefTenant = doc(dbTenant, 'rental_requests', 'prop_tx_1_tenant_1');

    // Create via transaction
    await runTransaction(dbTenant, async (tx) => {
      await tx.get(docRefTenant);
      tx.set(docRefTenant, validPayload);
    });

    const snap = await assertSucceeds(getDoc(docRefTenant));
    expect(snap.exists()).toBe(true);
    expect(snap.data().propertyTitle).toBe('Gulshan Modern Suite');
  });

  it('allows landlord to read request submitted for their property', async () => {
    const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
    const docRefTenant = doc(dbTenant, 'rental_requests', 'prop_tx_1_tenant_1');

    // Create via transaction
    await runTransaction(dbTenant, async (tx) => {
      await tx.get(docRefTenant);
      tx.set(docRefTenant, validPayload);
    });

    const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
    const docRefLandlord = doc(dbLandlord, 'rental_requests', 'prop_tx_1_tenant_1');
    const snap = await assertSucceeds(getDoc(docRefLandlord));
    expect(snap.exists()).toBe(true);
    expect(snap.data().ownerId).toBe('landlord_1');
  });

  it('denies stranger from reading existing rental request', async () => {
    const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
    const docRefTenant = doc(dbTenant, 'rental_requests', 'prop_tx_1_tenant_1');

    // Create via transaction
    await runTransaction(dbTenant, async (tx) => {
      await tx.get(docRefTenant);
      tx.set(docRefTenant, validPayload);
    });

    const dbStranger = testEnv.authenticatedContext('stranger_1').firestore();
    const docRefStranger = doc(dbStranger, 'rental_requests', 'prop_tx_1_tenant_1');
    await assertFails(getDoc(docRefStranger));
  });

  it('denies creating duplicate active request or resetting createdAt on existing pending request', async () => {
    const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
    const docRefTenant = doc(dbTenant, 'rental_requests', 'prop_tx_1_tenant_1');

    // Create initial pending request
    await runTransaction(dbTenant, async (tx) => {
      await tx.get(docRefTenant);
      tx.set(docRefTenant, validPayload);
    });

    // Attempting to overwrite existing pending request with new createdAt fails
    await assertFails(
      setDoc(docRefTenant, {
        ...validPayload,
        message: 'Second attempt with new timestamp',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies stranger from creating or overwriting request for another tenant via transaction', async () => {
    const dbStranger = testEnv.authenticatedContext('stranger_1').firestore();
    const docRef = doc(dbStranger, 'rental_requests', 'prop_tx_1_tenant_1');

    await assertFails(
      runTransaction(dbStranger, async (tx) => {
        await tx.get(docRef);
        tx.set(docRef, {
          ...validPayload,
          tenantId: 'stranger_1',
        });
      })
    );
  });
});

// =============================================================================
// 5. Landlord Decisions (Accept / Reject)
// =============================================================================
describe('Firestore Security Rules: Landlord Decisions (Accept / Reject)', () => {
  beforeEach(async () => {
    await seedProperty('prop_1', { ownerId: 'landlord_1', status: 'approved' });
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'pending',
    });
  });

  it('allows landlord to accept a pending rental request', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'accepted',
        landlordNote: 'Welcome to the apartment!',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows landlord to reject a pending rental request with optional note', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'rejected',
        landlordNote: 'Property is currently unavailable',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from modifying tenant details during decision', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'accepted',
        tenantName: 'Tampered Tenant Name',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from altering an already accepted request to rejected', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'accepted',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'rejected',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from altering an already rejected request to accepted', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'rejected',
    });
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'accepted',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies landlord from cancelling a rental request', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies non-landlord from accepting or rejecting request', async () => {
    const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(dbTenant, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'accepted',
        updatedAt: serverTimestamp(),
      })
    );

    const dbStranger = testEnv.authenticatedContext('stranger_1').firestore();
    await assertFails(
      updateDoc(doc(dbStranger, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'accepted',
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// =============================================================================
// 6. Tenant Cancellation
// =============================================================================
describe('Firestore Security Rules: Tenant Cancellation', () => {
  beforeEach(async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'pending',
    });
  });

  it('allows tenant to cancel their pending rental request', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies tenant from cancelling an already accepted request', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'accepted',
    });
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies tenant from cancelling an already rejected request', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'rejected',
    });
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies tenant from altering message or extra fields during cancellation', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        message: 'Cancelled because unresponsive owner', // Unauthorized field edit during cancellation
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies non-tenant from cancelling a rental request', async () => {
    const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(
      updateDoc(doc(dbLandlord, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      })
    );

    const dbStranger = testEnv.authenticatedContext('stranger_1').firestore();
    await assertFails(
      updateDoc(doc(dbStranger, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// =============================================================================
// 7. Tenant Reapplication
// =============================================================================
describe('Firestore Security Rules: Tenant Reapplication', () => {
  beforeEach(async () => {
    // Seed approved property
    await seedProperty('prop_1', {
      ownerId: 'landlord_1',
      status: 'approved',
      title: 'Dhanmondi Cozy 2BHK',
      area: 'Dhanmondi',
    });
  });

  it('allows tenant to reapply after cancellation via updateDoc if property is approved', async () => {
    const createdAt = Timestamp.now();
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'cancelled',
      createdAt,
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'pending',
        landlordNote: null,
        tenantName: 'Karim Ahmed Reapplied',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Reapplying with updated move-in date',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/p.jpg',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows tenant to reapply after rejection via updateDoc if property is approved', async () => {
    const createdAt = Timestamp.now();
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'rejected',
      landlordNote: 'Previous rejection reason',
      createdAt,
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'pending',
        landlordNote: null,
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Reapplying with higher deposit readiness',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/p.jpg',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows tenant to reapply using setDoc with complete payload and existing createdAt (Flutter client pattern)', async () => {
    const originalCreatedAt = Timestamp.fromDate(new Date('2026-10-01T10:00:00Z'));
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'cancelled',
      createdAt: originalCreatedAt,
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    // Complete payload matching FirestoreService.createRentalRequest transaction.set pattern
    await assertSucceeds(
      setDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        propertyId: 'prop_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        tenantEmail: 'tenant@example.com',
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        message: 'Reapplying via setDoc like Flutter client',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/photo.jpg',
        status: 'pending',
        landlordNote: null,
        createdAt: originalCreatedAt,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies tenant from reapplying while request is still pending (with valid full payload)', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'pending', // Current status is already pending
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    // Payload contains all valid fields; fails solely because current status is 'pending'
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'pending',
        landlordNote: null,
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Trying to overwrite active pending request',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/photo.jpg',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies tenant from reapplying when request is accepted', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'accepted',
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'pending',
        landlordNote: null,
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Overwriting accepted request',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/p.jpg',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies reapplication if landlordNote is not cleared to null', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'rejected',
      landlordNote: 'Previous rejection note',
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'pending',
        landlordNote: 'Retaining old landlord note', // Must be null on reapplication
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Reapplying with uncleared landlord note',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: 'https://example.com/photo.jpg',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies reapplication if referenced property has been deleted', async () => {
    await seedRentalRequest('prop_deleted_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_deleted',
      status: 'cancelled',
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_deleted_tenant_1'), {
        status: 'pending',
        landlordNote: null,
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Reapplying to deleted property',
        propertyTitle: 'Deleted Property',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: null,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies reapplication if property is no longer approved', async () => {
    await seedProperty('prop_unapproved', {
      ownerId: 'landlord_1',
      status: 'pending', // no longer approved
    });
    await seedRentalRequest('prop_unapproved_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_unapproved',
      status: 'cancelled',
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_unapproved_tenant_1'), {
        status: 'pending',
        landlordNote: null,
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Reapplying to unapproved property',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: null,
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies reapplication if immutable fields are modified', async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'cancelled',
    });

    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(
      updateDoc(doc(db, 'rental_requests', 'prop_1_tenant_1'), {
        status: 'pending',
        ownerId: 'different_landlord', // attempted change
        landlordNote: null,
        tenantName: 'Karim Ahmed',
        tenantPhone: '01700000000',
        preferredMoveIn: '2026-12-01',
        tenantEmail: 'tenant@example.com',
        message: 'Reapplying with modified owner',
        propertyTitle: 'Dhanmondi Cozy 2BHK',
        propertyArea: 'Dhanmondi',
        rentPerMonth: 25000,
        propertyPhotoUrl: null,
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// =============================================================================
// 8. Deletion & Default Catch-All Deny
// =============================================================================
describe('Firestore Security Rules: Deletion & Default Catch-All Deny', () => {
  beforeEach(async () => {
    await seedRentalRequest('prop_1_tenant_1', {
      tenantId: 'tenant_1',
      ownerId: 'landlord_1',
      propertyId: 'prop_1',
      status: 'pending',
    });
  });

  it('denies tenant from deleting a rental request', async () => {
    const db = testEnv.authenticatedContext('tenant_1').firestore();
    await assertFails(deleteDoc(doc(db, 'rental_requests', 'prop_1_tenant_1')));
  });

  it('denies landlord from deleting a rental request', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertFails(deleteDoc(doc(db, 'rental_requests', 'prop_1_tenant_1')));
  });

  it('denies access to arbitrary unlisted collections (default catch-all deny)', async () => {
    const dbAuth = testEnv.authenticatedContext('any_user').firestore();
    await assertFails(getDoc(doc(dbAuth, 'admin_secrets', 'secret_token')));
    await assertFails(
      setDoc(doc(dbAuth, 'admin_secrets', 'secret_token'), { key: 'val' })
    );

    const dbUnauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(dbUnauth, 'system_data', 'config')));
    await assertFails(
      setDoc(doc(dbUnauth, 'system_data', 'config'), { hack: true })
    );
  });
});

// =============================================================================
// 9. Landlord Contact Info (/properties/{propertyId}/contact_info/{docId})
// =============================================================================
describe('Firestore Security Rules: Landlord Contact Info (/properties/{propertyId}/contact_info/{docId})', () => {
  beforeEach(async () => {
    // Seed approved property owned by landlord_1
    await seedProperty('prop_contact_1', {
      ownerId: 'landlord_1',
      status: 'approved',
      title: 'Gulshan Garden View Flat',
      area: 'Gulshan 1',
    });
  });

  it('allows landlord to create contact info on their own property', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'), {
        ownerId: 'landlord_1',
        propertyId: 'prop_contact_1',
        phone: '01712345678',
        whatsapp: '01712345678',
        email: 'landlord@example.com',
        otherTitle: 'Messenger',
        otherLink: 'https://m.me/landlord',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows landlord to update contact info on their own property', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      phone: '01712345678',
    });

    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'), {
        phone: '01899999999',
        whatsapp: '01899999999',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies non-owner from creating contact info on someone else property', async () => {
    const db = testEnv.authenticatedContext('stranger_landlord').firestore();
    await assertFails(
      setDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'), {
        ownerId: 'stranger_landlord',
        propertyId: 'prop_contact_1',
        phone: '01700000000',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('denies non-owner from updating contact info on someone else property', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });

    const db = testEnv.authenticatedContext('stranger_landlord').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'), {
        phone: '01999999999',
        updatedAt: serverTimestamp(),
      })
    );
  });

  it('allows landlord to read their own property contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });

    const db = testEnv.authenticatedContext('landlord_1').firestore();
    await assertSucceeds(
      getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  it('allows tenant with accepted request to read landlord contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });
    await seedRentalRequest('prop_contact_1_tenant_accepted', {
      tenantId: 'tenant_accepted',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'accepted',
    });

    const db = testEnv.authenticatedContext('tenant_accepted').firestore();
    await assertSucceeds(
      getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  it('allows tenant with accepted request to read contact doc even if doc does not exist yet', async () => {
    await seedRentalRequest('prop_contact_1_tenant_acc_nodoc', {
      tenantId: 'tenant_acc_nodoc',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'accepted',
    });

    const db = testEnv.authenticatedContext('tenant_acc_nodoc').firestore();
    const snap = await getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details_nodoc'));
    expect(snap.exists()).toBe(false);
  });

  it('allows landlord to read non-existent contact doc before creating it', async () => {
    const db = testEnv.authenticatedContext('landlord_1').firestore();
    const snap = await getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'non_existent_doc'));
    expect(snap.exists()).toBe(false);
  });

  it('denies tenant with pending request from reading landlord contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });
    await seedRentalRequest('prop_contact_1_tenant_pending', {
      tenantId: 'tenant_pending',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'pending',
    });

    const db = testEnv.authenticatedContext('tenant_pending').firestore();
    await assertFails(
      getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  it('denies tenant with rejected request from reading landlord contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });
    await seedRentalRequest('prop_contact_1_tenant_rejected', {
      tenantId: 'tenant_rejected',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'rejected',
    });

    const db = testEnv.authenticatedContext('tenant_rejected').firestore();
    await assertFails(
      getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  it('denies tenant with cancelled request from reading landlord contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });
    await seedRentalRequest('prop_contact_1_tenant_cancelled', {
      tenantId: 'tenant_cancelled',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'cancelled',
    });

    const db = testEnv.authenticatedContext('tenant_cancelled').firestore();
    await assertFails(
      getDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  it('denies another tenant from reading contact info even when first tenant request is accepted', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });
    // Tenant A is accepted
    await seedRentalRequest('prop_contact_1_tenant_A', {
      tenantId: 'tenant_A',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'accepted',
    });
    // Tenant B has pending request
    await seedRentalRequest('prop_contact_1_tenant_B', {
      tenantId: 'tenant_B',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'pending',
    });

    // Tenant B must be denied!
    const dbB = testEnv.authenticatedContext('tenant_B').firestore();
    await assertFails(
      getDoc(doc(dbB, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );

    // Tenant C with no request must also be denied!
    const dbC = testEnv.authenticatedContext('tenant_C').firestore();
    await assertFails(
      getDoc(doc(dbC, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  it('denies unauthenticated user from reading or writing contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });

    const dbUnauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(dbUnauth, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
    await assertFails(
      setDoc(doc(dbUnauth, 'properties', 'prop_contact_1', 'contact_info', 'details'), {
        ownerId: 'anyone',
        phone: '123456',
      })
    );
  });

  it('denies accepted tenant from updating or deleting landlord contact info', async () => {
    await seedContactInfo('prop_contact_1', 'details', {
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
    });
    await seedRentalRequest('prop_contact_1_tenant_accepted', {
      tenantId: 'tenant_accepted',
      ownerId: 'landlord_1',
      propertyId: 'prop_contact_1',
      status: 'accepted',
    });

    const db = testEnv.authenticatedContext('tenant_accepted').firestore();
    await assertFails(
      updateDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'), {
        phone: '01000000000',
        updatedAt: serverTimestamp(),
      })
    );
    await assertFails(
      deleteDoc(doc(db, 'properties', 'prop_contact_1', 'contact_info', 'details'))
    );
  });

  // =============================================================================
  // In-App Chat & Messaging Security Tests (/conversations/{id})
  // =============================================================================
  describe('Firestore Security Rules: In-App Chat & Messaging (/conversations/{id})', () => {
    it('allows tenant to create conversation when rental request is accepted', async () => {
      await seedRentalRequest('prop_chat_1_tenant_1', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertSucceeds(
        setDoc(doc(dbTenant, 'conversations', 'prop_chat_1_tenant_1'), {
          requestId: 'prop_chat_1_tenant_1',
          propertyId: 'prop_chat_1',
          propertyTitle: 'Chat Flat',
          ownerId: 'landlord_1',
          tenantId: 'tenant_1',
          tenantName: 'Tenant One',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('allows landlord to create conversation when rental request is accepted', async () => {
      await seedRentalRequest('prop_chat_1_tenant_1', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });

      const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
      await assertSucceeds(
        setDoc(doc(dbLandlord, 'conversations', 'prop_chat_1_tenant_1'), {
          requestId: 'prop_chat_1_tenant_1',
          propertyId: 'prop_chat_1',
          propertyTitle: 'Chat Flat',
          ownerId: 'landlord_1',
          tenantId: 'tenant_1',
          tenantName: 'Tenant One',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies conversation creation when rental request is still pending', async () => {
      await seedRentalRequest('prop_chat_1_tenant_pending', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_pending',
        status: 'pending',
      });

      const db = testEnv.authenticatedContext('tenant_pending').firestore();
      await assertFails(
        setDoc(doc(db, 'conversations', 'prop_chat_1_tenant_pending'), {
          requestId: 'prop_chat_1_tenant_pending',
          propertyId: 'prop_chat_1',
          propertyTitle: 'Chat Flat',
          ownerId: 'landlord_1',
          tenantId: 'tenant_pending',
          tenantName: 'Tenant Pending',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies conversation creation when rental request was rejected', async () => {
      await seedRentalRequest('prop_chat_1_tenant_rejected', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_rejected',
        status: 'rejected',
      });

      const db = testEnv.authenticatedContext('tenant_rejected').firestore();
      await assertFails(
        setDoc(doc(db, 'conversations', 'prop_chat_1_tenant_rejected'), {
          requestId: 'prop_chat_1_tenant_rejected',
          propertyId: 'prop_chat_1',
          propertyTitle: 'Chat Flat',
          ownerId: 'landlord_1',
          tenantId: 'tenant_rejected',
          tenantName: 'Tenant Rejected',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies nonparticipant from creating conversation', async () => {
      await seedRentalRequest('prop_chat_1_tenant_1', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });

      const dbAttacker = testEnv.authenticatedContext('attacker_user').firestore();
      await assertFails(
        setDoc(doc(dbAttacker, 'conversations', 'prop_chat_1_tenant_1'), {
          requestId: 'prop_chat_1_tenant_1',
          propertyId: 'prop_chat_1',
          propertyTitle: 'Chat Flat',
          ownerId: 'landlord_1',
          tenantId: 'tenant_1',
          tenantName: 'Tenant One',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('allows participants to read conversation document', async () => {
      await seedConversation('prop_chat_1_tenant_1');

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertSucceeds(getDoc(doc(dbTenant, 'conversations', 'prop_chat_1_tenant_1')));

      const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
      await assertSucceeds(getDoc(doc(dbLandlord, 'conversations', 'prop_chat_1_tenant_1')));
    });

    it('denies nonparticipants from reading conversation document', async () => {
      await seedConversation('prop_chat_1_tenant_1');

      const dbStranger = testEnv.authenticatedContext('stranger_user').firestore();
      await assertFails(getDoc(doc(dbStranger, 'conversations', 'prop_chat_1_tenant_1')));

      const dbAnon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(dbAnon, 'conversations', 'prop_chat_1_tenant_1')));
    });

    it('allows participants to read non-existent conversation (getDoc) when linked rental request is accepted', async () => {
      // Rental request is accepted, but conversation document is NOT yet created (simulates getOrCreateConversation)
      await seedRentalRequest('prop_nonexist_tenant_1', {
        propertyId: 'prop_nonexist',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      const tenantSnap = await assertSucceeds(getDoc(doc(dbTenant, 'conversations', 'prop_nonexist_tenant_1')));
      expect(tenantSnap.exists()).toBe(false);

      const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
      const landlordSnap = await assertSucceeds(getDoc(doc(dbLandlord, 'conversations', 'prop_nonexist_tenant_1')));
      expect(landlordSnap.exists()).toBe(false);
    });

    it('denies read of non-existent conversation when linked rental request is pending or rejected', async () => {
      // Case A: Pending rental request
      await seedRentalRequest('prop_pend_tenant_1', {
        propertyId: 'prop_pend',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'pending',
      });
      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(getDoc(doc(dbTenant, 'conversations', 'prop_pend_tenant_1')));

      // Case B: Rejected rental request
      await seedRentalRequest('prop_rej_tenant_1', {
        propertyId: 'prop_rej',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'rejected',
      });
      await assertFails(getDoc(doc(dbTenant, 'conversations', 'prop_rej_tenant_1')));
    });

    it('denies read of non-existent conversation when linked rental request is missing or by nonparticipant', async () => {
      // Case A: Missing rental request
      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(getDoc(doc(dbTenant, 'conversations', 'completely_missing_req_tenant_1')));

      // Case B: Accepted rental request, but read attempted by unrelated stranger
      await seedRentalRequest('prop_secret_tenant_1', {
        propertyId: 'prop_secret',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });
      const dbStranger = testEnv.authenticatedContext('stranger_intruder').firestore();
      await assertFails(getDoc(doc(dbStranger, 'conversations', 'prop_secret_tenant_1')));

      // Case C: Unauthenticated user
      const dbAnon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(dbAnon, 'conversations', 'prop_secret_tenant_1')));
    });

    it('allows participant to send message in authorized conversation', async () => {
      await seedRentalRequest('prop_chat_1_tenant_1', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });
      await seedConversation('prop_chat_1_tenant_1');

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertSucceeds(
        setDoc(doc(dbTenant, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_1'), {
          conversationId: 'prop_chat_1_tenant_1',
          senderId: 'tenant_1',
          text: 'Hello landlord, when can I move in?',
          createdAt: serverTimestamp(),
        })
      );

      const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
      await assertSucceeds(
        setDoc(doc(dbLandlord, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_2'), {
          conversationId: 'prop_chat_1_tenant_1',
          senderId: 'landlord_1',
          text: 'Hello! You are welcome starting 1st of next month.',
          createdAt: serverTimestamp(),
        })
      );
    });

    it('denies sender from spoofing senderId on message', async () => {
      await seedRentalRequest('prop_chat_1_tenant_1', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });
      await seedConversation('prop_chat_1_tenant_1');

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(
        setDoc(doc(dbTenant, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_spoofed'), {
          conversationId: 'prop_chat_1_tenant_1',
          senderId: 'landlord_1',
          text: 'I am the landlord, pay me now.',
          createdAt: serverTimestamp(),
        })
      );
    });

    it('denies nonparticipant from sending or reading messages', async () => {
      await seedRentalRequest('prop_chat_1_tenant_1', {
        propertyId: 'prop_chat_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });
      await seedConversation('prop_chat_1_tenant_1');

      const dbStranger = testEnv.authenticatedContext('stranger').firestore();
      await assertFails(
        setDoc(doc(dbStranger, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_eavesdrop'), {
          conversationId: 'prop_chat_1_tenant_1',
          senderId: 'stranger',
          text: 'Can I intrude?',
          createdAt: serverTimestamp(),
        })
      );

      await assertFails(
        getDoc(doc(dbStranger, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_1'))
      );
    });

    it('denies modifying or deleting sent messages (immutable chat)', async () => {
      await seedConversation('prop_chat_1_tenant_1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_immutable'), {
          conversationId: 'prop_chat_1_tenant_1',
          senderId: 'tenant_1',
          text: 'Original message text',
          createdAt: Timestamp.now(),
        });
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(
        updateDoc(doc(dbTenant, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_immutable'), {
          text: 'Altered message text',
        })
      );
      await assertFails(
        deleteDoc(doc(dbTenant, 'conversations', 'prop_chat_1_tenant_1', 'messages', 'msg_immutable'))
      );
    });

    it('allows tenant to query conversations with where(tenantId, ==, theirUid)', async () => {
      await seedConversation('prop_q1_tenant_1', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
      });
      await seedConversation('prop_q2_tenant_1', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_2',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      const q = query(
        collection(dbTenant, 'conversations'),
        where('tenantId', '==', 'tenant_1')
      );
      await assertSucceeds(getDocs(q));
    });

    it('allows landlord to query conversations with where(ownerId, ==, theirUid)', async () => {
      await seedConversation('prop_q1_landlord_1', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
      });
      await seedConversation('prop_q2_landlord_1', {
        tenantId: 'tenant_2',
        ownerId: 'landlord_1',
      });

      const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
      const q = query(
        collection(dbLandlord, 'conversations'),
        where('ownerId', '==', 'landlord_1')
      );
      await assertSucceeds(getDocs(q));
    });

    it('denies unrelated user from querying conversations of other tenants or landlords', async () => {
      await seedConversation('prop_q_private', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
      });

      const dbStranger = testEnv.authenticatedContext('stranger_eavesdropper').firestore();

      // Attempt querying another tenant's conversations
      const qTenant = query(
        collection(dbStranger, 'conversations'),
        where('tenantId', '==', 'tenant_1')
      );
      await assertFails(getDocs(qTenant));

      // Attempt querying another landlord's conversations
      const qOwner = query(
        collection(dbStranger, 'conversations'),
        where('ownerId', '==', 'landlord_1')
      );
      await assertFails(getDocs(qOwner));
    });

    it('denies unfiltered collection queries on conversations', async () => {
      await seedConversation('prop_q_unfiltered', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(getDocs(collection(dbTenant, 'conversations')));

      const dbAnon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDocs(collection(dbAnon, 'conversations')));
    });

    it('denies unauthenticated users from querying conversations by tenantId or ownerId', async () => {
      await seedConversation('prop_q_unauth', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
      });

      const dbAnon = testEnv.unauthenticatedContext().firestore();
      const qTenant = query(
        collection(dbAnon, 'conversations'),
        where('tenantId', '==', 'tenant_1')
      );
      await assertFails(getDocs(qTenant));

      const qOwner = query(
        collection(dbAnon, 'conversations'),
        where('ownerId', '==', 'landlord_1')
      );
      await assertFails(getDocs(qOwner));
    });

    it('allows participant queries even when linked rental request is absent (verifying list does not depend on external get)', async () => {
      // Conversation exists, but no rental request is seeded in /rental_requests
      await seedConversation('prop_orphan_conv_tenant_1', {
        tenantId: 'tenant_1',
        ownerId: 'landlord_1',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      const qTenant = query(
        collection(dbTenant, 'conversations'),
        where('tenantId', '==', 'tenant_1')
      );
      await assertSucceeds(getDocs(qTenant));

      const dbLandlord = testEnv.authenticatedContext('landlord_1').firestore();
      const qOwner = query(
        collection(dbLandlord, 'conversations'),
        where('ownerId', '==', 'landlord_1')
      );
      await assertSucceeds(getDocs(qOwner));
    });

    it('allows conversation metadata update while linked rental request is accepted', async () => {
      await seedRentalRequest('prop_up_1_tenant_1', {
        propertyId: 'prop_up_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });
      await seedConversation('prop_up_1_tenant_1', {
        requestId: 'prop_up_1_tenant_1',
        propertyId: 'prop_up_1',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertSucceeds(
        updateDoc(doc(dbTenant, 'conversations', 'prop_up_1_tenant_1'), {
          lastMessageText: 'See you tomorrow at 4 PM.',
          lastMessageSenderId: 'tenant_1',
          lastMessageAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies conversation metadata update after linked rental request is cancelled or rejected', async () => {
      // 1. Seed as accepted initially
      await seedRentalRequest('prop_revoked_tenant_1', {
        propertyId: 'prop_revoked',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
        status: 'accepted',
      });
      await seedConversation('prop_revoked_tenant_1', {
        requestId: 'prop_revoked_tenant_1',
        propertyId: 'prop_revoked',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
      });

      // 2. Change rental request status to cancelled via testEnv
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await updateDoc(doc(db, 'rental_requests', 'prop_revoked_tenant_1'), {
          status: 'cancelled',
        });
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(
        updateDoc(doc(dbTenant, 'conversations', 'prop_revoked_tenant_1'), {
          lastMessageText: 'Attempting update after cancellation',
          lastMessageSenderId: 'tenant_1',
          lastMessageAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );

      // 3. Change rental request status to rejected via testEnv
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await updateDoc(doc(db, 'rental_requests', 'prop_revoked_tenant_1'), {
          status: 'rejected',
        });
      });

      await assertFails(
        updateDoc(doc(dbTenant, 'conversations', 'prop_revoked_tenant_1'), {
          lastMessageText: 'Attempting update after rejection',
          lastMessageSenderId: 'tenant_1',
          lastMessageAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies conversation metadata update when linked rental request document is missing', async () => {
      await seedConversation('prop_missing_req_tenant_1', {
        requestId: 'non_existent_rental_req',
        propertyId: 'prop_missing_req',
        ownerId: 'landlord_1',
        tenantId: 'tenant_1',
      });

      const dbTenant = testEnv.authenticatedContext('tenant_1').firestore();
      await assertFails(
        updateDoc(doc(dbTenant, 'conversations', 'prop_missing_req_tenant_1'), {
          lastMessageText: 'Attempting update without rental request',
          lastMessageSenderId: 'tenant_1',
          lastMessageAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });
  });

  describe('Media Cleanup Tasks Security Rules (/media_cleanup_tasks/{taskId})', () => {
    it('denies property owner from creating cleanup task for their own property assets directly from client', async () => {
      const dbOwner = testEnv.authenticatedContext('landlord_1').firestore();
      await assertFails(
        setDoc(doc(dbOwner, 'media_cleanup_tasks', 'task_owner_valid'), {
          ownerId: 'landlord_1',
          propertyId: 'prop_123',
          publicId: 'properties/landlord_1/prop_123/photo_1',
          status: 'pending',
          retryCount: 0,
          reason: 'photo_removed_during_edit',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies user from creating cleanup task for another owner assets (cross-tenant attack)', async () => {
      const dbAttacker = testEnv.authenticatedContext('attacker_user').firestore();
      // Attacker tries to delete landlord_1's photo by submitting their publicId
      await assertFails(
        setDoc(doc(dbAttacker, 'media_cleanup_tasks', 'task_attack_cross_tenant'), {
          ownerId: 'attacker_user',
          propertyId: 'prop_123',
          publicId: 'properties/landlord_1/prop_123/photo_1',
          status: 'pending',
          retryCount: 0,
          reason: 'photo_removed_during_edit',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies user from spoofing ownerId field with victim uid', async () => {
      const dbAttacker = testEnv.authenticatedContext('attacker_user').firestore();
      // Attacker specifies landlord_1 in ownerId field
      await assertFails(
        setDoc(doc(dbAttacker, 'media_cleanup_tasks', 'task_attack_spoof_owner'), {
          ownerId: 'landlord_1',
          propertyId: 'prop_123',
          publicId: 'properties/landlord_1/prop_123/photo_1',
          status: 'pending',
          retryCount: 0,
          reason: 'property_deleted',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        })
      );
    });

    it('denies client from updating or deleting media cleanup task', async () => {
      // Seed a task
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'media_cleanup_tasks', 'task_immutable'), {
          ownerId: 'landlord_1',
          propertyId: 'prop_123',
          publicId: 'properties/landlord_1/prop_123/photo_1',
          status: 'pending',
          retryCount: 0,
          reason: 'property_deleted',
        });
      });

      const dbOwner = testEnv.authenticatedContext('landlord_1').firestore();
      // Attempt to mark completed directly from client
      await assertFails(
        updateDoc(doc(dbOwner, 'media_cleanup_tasks', 'task_immutable'), {
          status: 'completed',
        })
      );
      // Attempt to delete directly from client
      await assertFails(
        deleteDoc(doc(dbOwner, 'media_cleanup_tasks', 'task_immutable'))
      );
    });

    it('allows owner to read task, denies unrelated stranger', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'media_cleanup_tasks', 'task_read_test'), {
          ownerId: 'landlord_1',
          propertyId: 'prop_123',
          publicId: 'properties/landlord_1/prop_123/photo_1',
          status: 'pending',
          retryCount: 0,
          reason: 'property_deleted',
        });
      });

      const dbOwner = testEnv.authenticatedContext('landlord_1').firestore();
      await assertSucceeds(getDoc(doc(dbOwner, 'media_cleanup_tasks', 'task_read_test')));

      const dbStranger = testEnv.authenticatedContext('stranger_user').firestore();
      await assertFails(getDoc(doc(dbStranger, 'media_cleanup_tasks', 'task_read_test')));
    });
  });
});
