const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const {
  createUploadSignature,
  evaluateMediaCleanup,
  processMediaCleanupTask,
  processPendingMediaCleanupTasks,
  checkAndIncrementSignatureRateLimit,
  verifyPropertyUploadAuthorization,
  executeDurablePropertyDeletion,
  handlePropertyDeletedSnapshot,
  DEFAULT_CLOUD_NAME,
  MAX_CLEANUP_RETRIES,
  MAX_SIGNATURES_PER_WINDOW,
  WINDOW_DURATION_MS,
  LEASE_EXPIRATION_MS,
} = require('../index.js');

test('Cloudinary Security: createUploadSignature generates valid canonical HMAC-SHA1 signature', () => {
  const ownerId = 'user_abc123';
  const propertyId = 'prop_xyz789';
  const timestamp = 1730000000;
  const apiSecret = 'test_secret_key_12345';
  const apiKey = '123456789012345';

  const result = createUploadSignature({
    ownerId,
    propertyId,
    timestamp,
    apiSecret,
    apiKey,
  });

  assert.equal(result.apiKey, apiKey);
  assert.equal(result.timestamp, timestamp);
  assert.equal(result.cloudName, DEFAULT_CLOUD_NAME);
  assert.equal(result.folder, 'properties/user_abc123/prop_xyz789');

  // Verify signature algorithm manually:
  // Alphabetical sort of: folder, tags, timestamp, upload_preset
  const expectedStringToSign = `folder=properties/user_abc123/prop_xyz789&tags=basha_lagbe,property&timestamp=1730000000&upload_preset=bashalagbe_properties_signed${apiSecret}`;
  const expectedHash = crypto.createHash('sha1').update(expectedStringToSign).digest('hex');

  assert.equal(result.signature, expectedHash);
});

test('Cloudinary Security: rejects path traversal and invalid characters in ownerId or propertyId', () => {
  assert.throws(() => {
    createUploadSignature({
      ownerId: '../evil_user',
      propertyId: 'prop_123',
      timestamp: 1730000000,
      apiSecret: 'secret',
      apiKey: 'key',
    });
  }, /Invalid characters/);

  assert.throws(() => {
    createUploadSignature({
      ownerId: 'user_123',
      propertyId: 'prop/subpath',
      timestamp: 1730000000,
      apiSecret: 'secret',
      apiKey: 'key',
    });
  }, /Invalid characters/);
});

test('Cloudinary Security: rejects empty required parameters', () => {
  assert.throws(() => {
    createUploadSignature({
      ownerId: '',
      propertyId: 'prop_123',
      timestamp: 1730000000,
      apiSecret: 'secret',
      apiKey: 'key',
    });
  }, /ownerId is required/);

  assert.throws(() => {
    createUploadSignature({
      ownerId: 'user_123',
      propertyId: 'prop_123',
      timestamp: 1730000000,
      apiSecret: '',
      apiKey: 'key',
    });
  }, /apiSecret is required/);
});

test('Cloudinary Lifecycle: evaluateMediaCleanup skips destruction if asset is still referenced in property photos array', async () => {
  // Mock Firestore returning a property that contains this photo storagePath
  const mockFirestore = {
    collection: (name) => {
      assert.equal(name, 'properties');
      return {
        where: (field, op, val) => {
          assert.equal(field, 'ownerId');
          assert.equal(val, 'u1');
          return {
            get: async () => ({
              empty: false,
              docs: [
                {
                  id: 'prop_active_1',
                  data: () => ({
                    ownerId: 'u1',
                    photos: [
                      {
                        label: 'Master Bedroom',
                        storagePath: 'properties/u1/p1/photo_1',
                        imageUrl: 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1/properties/u1/p1/photo_1.jpg',
                      },
                    ],
                  }),
                },
              ],
            }),
          };
        },
      };
    },
  };

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        assert.fail('destroy must not be called when asset is still in use');
      },
    },
  };

  const result = await evaluateMediaCleanup({
    task: { publicId: 'properties/u1/p1/photo_1', ownerId: 'u1', propertyId: 'p1' },
    firestore: mockFirestore,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.action, 'skipped_in_use');
  assert.match(result.reason, /referenced by property "prop_active_1"/);
});

test('Cloudinary Lifecycle: evaluateMediaCleanup skips destruction if asset is referenced as top-level imageUrl', async () => {
  const mockFirestore = {
    collection: () => ({
      where: () => ({
        get: async () => ({
          empty: false,
          docs: [
            {
              id: 'prop_cover_only',
              data: () => ({
                ownerId: 'u1',
                imageUrl: 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1/properties/u1/p1/cover.jpg',
                photos: [],
              }),
            },
          ],
        }),
      }),
    }),
  };

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        assert.fail('destroy must not be called when cover image is in use');
      },
    },
  };

  const result = await evaluateMediaCleanup({
    task: { publicId: 'properties/u1/p1/cover', ownerId: 'u1', propertyId: 'p1' },
    firestore: mockFirestore,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.action, 'skipped_in_use');
  assert.match(result.reason, /referenced as top-level cover image/);
});

test('Cloudinary Lifecycle: evaluateMediaCleanup conservatively skips deletion if Firestore lookup fails', async () => {
  const mockFirestore = {
    collection: () => ({
      where: () => ({
        get: async () => {
          throw new Error('Firestore connection timeout');
        },
      }),
    }),
  };

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        assert.fail('destroy must not be called if lookup fails');
      },
    },
  };

  const result = await evaluateMediaCleanup({
    task: { publicId: 'properties/u1/p1/photo_err', ownerId: 'u1' },
    firestore: mockFirestore,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.action, 'skipped_error');
  assert.match(result.reason, /Conservatively aborted deletion/);
});

test('Cloudinary Lifecycle: evaluateMediaCleanup proceeds to destroy unreferenced asset in Cloudinary', async () => {
  // Mock Firestore returning empty or doc without this photo
  const mockFirestore = {
    collection: () => ({
      where: () => ({
        get: async () => ({
          empty: false,
          docs: [
            {
              id: 'prop_other',
              data: () => ({
                ownerId: 'u1',
                photos: [
                  { storagePath: 'properties/u1/other/photo_99' },
                ],
              }),
            },
          ],
        }),
      }),
    }),
  };

  let destroyedPublicId = null;
  const mockCloudinary = {
    uploader: {
      destroy: async (publicId) => {
        destroyedPublicId = publicId;
        return { result: 'ok' };
      },
    },
  };

  const result = await evaluateMediaCleanup({
    task: { publicId: 'properties/u1/p1/photo_deleted_1', ownerId: 'u1' },
    firestore: mockFirestore,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.action, 'completed');
  assert.equal(result.result, 'ok');
  assert.equal(destroyedPublicId, 'properties/u1/p1/photo_deleted_1');
});

test('Property Deletion Race: evaluateMediaCleanup returns retry_pending_deletion if target property is still in Firestore', async () => {
  const mockFirestore = {
    collection: () => ({
      where: () => ({
        get: async () => ({
          empty: false,
          docs: [
            {
              id: 'prop_being_deleted',
              data: () => ({
                ownerId: 'u1',
                photos: [
                  { storagePath: 'properties/u1/prop_being_deleted/photo_1' },
                ],
              }),
            },
          ],
        }),
      }),
    }),
  };

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        assert.fail('destroy must not be called during grace retry');
      },
    },
  };

  const result = await evaluateMediaCleanup({
    task: {
      publicId: 'properties/u1/prop_being_deleted/photo_1',
      ownerId: 'u1',
      propertyId: 'prop_being_deleted',
      reason: 'property_deleted',
    },
    firestore: mockFirestore,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.action, 'retry_pending_deletion');
  assert.match(result.reason, /Retrying cleanup to allow deletion to complete/);
});

// -----------------------------------------------------------------------------
// In-Memory Multi-Collection Store Helper
// -----------------------------------------------------------------------------

function createInMemoryTaskStore(initialTasks = {}, initialProperties = {}, initialRateLimits = {}) {
  const taskStore = new Map();
  for (const [id, data] of Object.entries(initialTasks)) {
    taskStore.set(id, { ...data });
  }

  const propStore = new Map();
  for (const [id, data] of Object.entries(initialProperties)) {
    propStore.set(id, { ...data });
  }

  const rateLimitStore = new Map();
  for (const [id, data] of Object.entries(initialRateLimits)) {
    rateLimitStore.set(id, { ...data });
  }

  let txQueue = Promise.resolve();

  const firestore = {
    batch: () => {
      const ops = [];
      return {
        set: (ref, data) => {
          ops.push(() => {
            const docId = ref._id || ref.id;
            const store = ref._collection === 'rate_limits' ? rateLimitStore : (ref._collection === 'properties' ? propStore : taskStore);
            store.set(docId, { ...data });
          });
        },
        delete: (ref) => {
          ops.push(() => {
            const docId = ref._id || ref.id;
            const store = ref._collection === 'properties' ? propStore : taskStore;
            store.delete(docId);
          });
        },
        commit: async () => {
          for (const op of ops) op();
        },
      };
    },
    collection: (colName) => {
      if (colName === 'properties') {
        return {
          doc: (id) => ({
            _id: id,
            _collection: 'properties',
            collection: (subCol) => ({
              doc: (subId) => ({
                _id: `${id}_${subCol}_${subId}`,
                _collection: 'contact_info',
                delete: async () => {},
              }),
            }),
            get: async () => ({
              exists: propStore.has(id),
              data: () => propStore.get(id),
            }),
            delete: async () => {
              propStore.delete(id);
            },
          }),
          where: (field, op, val) => ({
            get: async () => {
              const matching = [];
              for (const [id, data] of propStore.entries()) {
                if (data[field] === val) matching.push({ id, data: () => data });
              }
              return { empty: matching.length === 0, docs: matching };
            },
          }),
        };
      }

      if (colName === 'rate_limits') {
        return {
          doc: (id) => ({
            _id: id,
            _collection: 'rate_limits',
            get: async () => ({
              exists: rateLimitStore.has(id),
              data: () => rateLimitStore.get(id),
            }),
          }),
        };
      }

      // Default: media_cleanup_tasks
      return {
        doc: (id) => ({
          _id: id,
          id: id,
          _collection: 'media_cleanup_tasks',
          get: async () => ({
            exists: taskStore.has(id),
            data: () => taskStore.get(id),
          }),
          update: async (updates) => {
            const current = taskStore.get(id) || {};
            taskStore.set(id, { ...current, ...updates });
          },
          set: async (data) => {
            taskStore.set(id, { ...data });
          },
        }),
        where: (field, op, val) => ({
          limit: (limitNum) => ({
            get: async () => {
              const matching = [];
              for (const [id, data] of taskStore.entries()) {
                let match = false;
                if (op === 'in' && Array.isArray(val)) {
                  match = val.includes(data[field]);
                } else if (op === '==') {
                  match = data[field] === val;
                }
                if (match) matching.push({ id, data: () => data });
                if (matching.length >= limitNum) break;
              }
              return { empty: matching.length === 0, docs: matching };
            },
          }),
        }),
      };
    },
    runTransaction: async (fn) => {
      // Chain transactions serially as Firestore does with document locks
      const execute = async () => {
        const transaction = {
          get: async (ref) => {
            const docId = ref.id || ref._id || 'task_1';
            const store = ref._collection === 'rate_limits' ? rateLimitStore : (ref._collection === 'properties' ? propStore : taskStore);
            return {
              exists: store.has(docId),
              data: () => store.get(docId),
            };
          },
          update: (ref, updates) => {
            const docId = ref.id || ref._id || 'task_1';
            const store = ref._collection === 'rate_limits' ? rateLimitStore : (ref._collection === 'properties' ? propStore : taskStore);
            const current = store.get(docId) || {};
            store.set(docId, { ...current, ...updates });
          },
          set: (ref, data) => {
            const docId = ref.id || ref._id || 'task_1';
            const store = ref._collection === 'rate_limits' ? rateLimitStore : (ref._collection === 'properties' ? propStore : taskStore);
            store.set(docId, { ...data });
          },
        };
        return await fn(transaction);
      };

      const next = txQueue.then(execute, execute);
      txQueue = next;
      return await next;
    },
    _store: taskStore,
    _rateLimits: rateLimitStore,
    _properties: propStore,
  };

  return firestore;
}

test('Cleanup Worker: processMediaCleanupTask successfully completes cleanup and updates status', async () => {
  const mockDb = createInMemoryTaskStore({
    task_1: {
      publicId: 'properties/user1/prop1/photo1',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'pending',
      retryCount: 0,
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => ({ result: 'ok' }),
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_1',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'completed');
  const taskInDb = mockDb._store.get('task_1');
  assert.equal(taskInDb.status, 'completed');
  assert.equal(taskInDb.retryCount, 1);
  assert.ok(taskInDb.completedAt);
});

test('Cleanup Worker: schedules retry with exponential backoff on transient failure (attempt 1)', async () => {
  const mockDb = createInMemoryTaskStore({
    task_1: {
      publicId: 'properties/user1/prop1/photo1',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'pending',
      retryCount: 0,
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        throw new Error('Cloudinary 503 Service Unavailable');
      },
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_1',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'retry_scheduled');
  const taskInDb = mockDb._store.get('task_1');
  assert.equal(taskInDb.status, 'retry_scheduled');
  assert.equal(taskInDb.retryCount, 1);
  assert.ok(taskInDb.nextRetryAt);
  assert.ok(taskInDb.lastAttemptAt);
  assert.match(taskInDb.error, /Cloudinary 503/);
});

test('Cleanup Worker: successful retry completes task and transitions to completed', async () => {
  const mockDb = createInMemoryTaskStore({
    task_1: {
      publicId: 'properties/user1/prop1/photo1',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'retry_scheduled',
      retryCount: 1,
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => ({ result: 'ok' }),
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_1',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'completed');
  const taskInDb = mockDb._store.get('task_1');
  assert.equal(taskInDb.status, 'completed');
  assert.equal(taskInDb.retryCount, 2);
  assert.ok(taskInDb.completedAt);
});

test('Cleanup Worker: records terminal failure and halts when MAX_CLEANUP_RETRIES is exceeded', async () => {
  const mockDb = createInMemoryTaskStore({
    task_1: {
      publicId: 'properties/user1/prop1/photo1',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'retry_scheduled',
      retryCount: 3,
    },
  });

  let destroyCalled = false;
  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        destroyCalled = true;
        return { result: 'ok' };
      },
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_1',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'skipped_duplicate_or_terminal');
  assert.equal(destroyCalled, false);
  const taskInDb = mockDb._store.get('task_1');
  assert.equal(taskInDb.status, 'failed');
  assert.match(taskInDb.error, /Exceeded maximum retry limit/);
  assert.ok(taskInDb.finalizedAt);
});

test('Cleanup Worker: prevents duplicate execution if task is already processing or completed', async () => {
  const mockDb = createInMemoryTaskStore({
    task_1: {
      publicId: 'properties/user1/prop1/photo1',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'processing',
      retryCount: 1,
      processingStartedAt: new Date().toISOString(), // fresh lease
    },
    task_2: {
      publicId: 'properties/user1/prop1/photo2',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'completed',
      retryCount: 1,
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => assert.fail('destroy must not be called'),
    },
  };

  const result1 = await processMediaCleanupTask({
    taskId: 'task_1',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });
  assert.equal(result1.status, 'skipped_duplicate_or_terminal');

  const result2 = await processMediaCleanupTask({
    taskId: 'task_2',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });
  assert.equal(result2.status, 'skipped_duplicate_or_terminal');
});

test('Lease Recovery: recovers and executes stale processing task when lease has expired', async () => {
  // Task started 20 minutes ago (lease limit is 15 minutes)
  const staleStartTime = new Date(Date.now() - 20 * 60 * 1000).toISOString();
  const mockDb = createInMemoryTaskStore({
    task_stale: {
      publicId: 'properties/user1/prop1/photo_stale',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'processing',
      retryCount: 1,
      processingStartedAt: staleStartTime,
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => ({ result: 'ok' }),
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_stale',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'completed');
  const taskInDb = mockDb._store.get('task_stale');
  assert.equal(taskInDb.status, 'completed');
  assert.equal(taskInDb.retryCount, 2);
});

test('Lease Recovery: batch processor recovers stale processing tasks and ignores active ones', async () => {
  const staleStartTime = new Date(Date.now() - 25 * 60 * 1000).toISOString();
  const freshStartTime = new Date(Date.now() - 2 * 60 * 1000).toISOString();

  const mockDb = createInMemoryTaskStore({
    task_stale: {
      _id: 'task_stale',
      publicId: 'properties/user1/prop1/photo_stale',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'processing',
      retryCount: 1,
      processingStartedAt: staleStartTime,
    },
    task_active: {
      _id: 'task_active',
      publicId: 'properties/user1/prop1/photo_active',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'processing',
      retryCount: 1,
      processingStartedAt: freshStartTime, // active lease
    },
  });

  const destroyed = [];
  const mockCloudinary = {
    uploader: {
      destroy: async (publicId) => {
        destroyed.push(publicId);
        return { result: 'ok' };
      },
    },
  };

  const summary = await processPendingMediaCleanupTasks({
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
    limit: 10,
    now: new Date(),
  });

  assert.equal(summary.processed, 1);
  assert.equal(summary.recoveredStale, 1);
  assert.equal(summary.completed, 1);
  assert.deepEqual(destroyed, ['properties/user1/prop1/photo_stale']);

  // task_active must remain untouched in processing status
  const activeTask = mockDb._store.get('task_active');
  assert.equal(activeTask.status, 'processing');
});

test('Cleanup Worker: permanent skip for malformed task or mismatched owner without retrying', async () => {
  const mockDb = createInMemoryTaskStore({
    task_1: {
      publicId: 'properties/victim/prop1/photo1',
      ownerId: 'attacker',
      propertyId: 'prop1',
      status: 'pending',
      retryCount: 0,
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        assert.fail('destroy must never be called for mismatched owner');
      },
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_1',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'skipped');
  const taskInDb = mockDb._store.get('task_1');
  assert.equal(taskInDb.status, 'skipped');
  assert.match(taskInDb.reason, /does not match publicId folder owner/);
});

test('Batch Processor: processPendingMediaCleanupTasks picks up eligible tasks and skips future retries', async () => {
  const pastTime = new Date(Date.now() - 60000).toISOString();
  const futureTime = new Date(Date.now() + 600000).toISOString();

  const mockDb = createInMemoryTaskStore({
    task_pending: {
      _id: 'task_pending',
      publicId: 'properties/user1/prop1/photo_pending',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'pending',
      retryCount: 0,
    },
    task_eligible_retry: {
      _id: 'task_eligible_retry',
      publicId: 'properties/user1/prop1/photo_retry',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'retry_scheduled',
      retryCount: 1,
      nextRetryAt: pastTime, // Backoff period elapsed, eligible!
    },
    task_future_retry: {
      _id: 'task_future_retry',
      publicId: 'properties/user1/prop1/photo_future',
      ownerId: 'user1',
      propertyId: 'prop1',
      status: 'retry_scheduled',
      retryCount: 1,
      nextRetryAt: futureTime, // In future, NOT eligible yet!
    },
  });

  const destroyed = [];
  const mockCloudinary = {
    uploader: {
      destroy: async (publicId) => {
        destroyed.push(publicId);
        return { result: 'ok' };
      },
    },
  };

  const summary = await processPendingMediaCleanupTasks({
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
    limit: 10,
    now: new Date(),
  });

  // Only task_pending and task_eligible_retry should have been processed
  assert.equal(summary.processed, 2);
  assert.equal(summary.completed, 2);
  assert.deepEqual(destroyed, [
    'properties/user1/prop1/photo_pending',
    'properties/user1/prop1/photo_retry',
  ]);

  // task_future_retry should still be retry_scheduled untouched
  const futureTask = mockDb._store.get('task_future_retry');
  assert.equal(futureTask.status, 'retry_scheduled');
});

// -----------------------------------------------------------------------------
// Rate Limiting Tests (checkAndIncrementSignatureRateLimit)
// -----------------------------------------------------------------------------

test('Rate Limiting: normal request succeeds and increments count', async () => {
  const mockDb = createInMemoryTaskStore();
  const ownerId = 'user_rate_1';

  const res1 = await checkAndIncrementSignatureRateLimit({
    firestore: mockDb,
    ownerId,
    now: 1000000,
    maxLimit: 30,
  });

  assert.equal(res1.allowed, true);
  assert.equal(res1.count, 1);
  assert.equal(res1.maxLimit, 30);

  const res2 = await checkAndIncrementSignatureRateLimit({
    firestore: mockDb,
    ownerId,
    now: 1001000,
    maxLimit: 30,
  });

  assert.equal(res2.allowed, true);
  assert.equal(res2.count, 2);
});

test('Rate Limiting: blocks requests when maxLimit is reached and returns resetInMs', async () => {
  const mockDb = createInMemoryTaskStore();
  const ownerId = 'user_rate_2';
  const startTime = 1000000;

  // Make 5 requests when maxLimit is 5
  for (let i = 0; i < 5; i++) {
    const res = await checkAndIncrementSignatureRateLimit({
      firestore: mockDb,
      ownerId,
      now: startTime + i * 1000,
      maxLimit: 5,
      windowDurationMs: 60000,
    });
    assert.equal(res.allowed, true);
    assert.equal(res.count, i + 1);
  }

  // 6th request should be rejected
  const blocked = await checkAndIncrementSignatureRateLimit({
    firestore: mockDb,
    ownerId,
    now: startTime + 6000,
    maxLimit: 5,
    windowDurationMs: 60000,
  });

  assert.equal(blocked.allowed, false);
  assert.equal(blocked.count, 5);
  // Reset time should be approximately (startTime + 60000) - (startTime + 6000) = 54000ms
  assert.equal(blocked.resetInMs, 54000);
});

test('Rate Limiting: prunes expired timestamps outside the sliding window', async () => {
  const mockDb = createInMemoryTaskStore();
  const ownerId = 'user_rate_3';
  const windowMs = 60000; // 1 minute window
  const startTime = 1000000;

  // Make 3 requests in the first minute
  for (let i = 0; i < 3; i++) {
    await checkAndIncrementSignatureRateLimit({
      firestore: mockDb,
      ownerId,
      now: startTime + i * 1000,
      maxLimit: 3,
      windowDurationMs: windowMs,
    });
  }

  // Next request 65 seconds later: all 3 previous timestamps have expired!
  const res = await checkAndIncrementSignatureRateLimit({
    firestore: mockDb,
    ownerId,
    now: startTime + 65000,
    maxLimit: 3,
    windowDurationMs: windowMs,
  });

  assert.equal(res.allowed, true);
  assert.equal(res.count, 1); // Reset to 1 active request in the window!
});

test('Rate Limiting: concurrent requests serialize atomically under transaction', async () => {
  const mockDb = createInMemoryTaskStore();
  const ownerId = 'user_rate_concurrent';

  // Fire 10 concurrent requests
  const promises = [];
  for (let i = 0; i < 10; i++) {
    promises.push(
      checkAndIncrementSignatureRateLimit({
        firestore: mockDb,
        ownerId,
        now: 1000000 + i * 10,
        maxLimit: 7, // Capped at 7
      })
    );
  }

  const results = await Promise.all(promises);
  const allowed = results.filter((r) => r.allowed);
  const blocked = results.filter((r) => !r.allowed);

  assert.equal(allowed.length, 7);
  assert.equal(blocked.length, 3);
});

// -----------------------------------------------------------------------------
// Property Ownership Authorization Tests (verifyPropertyUploadAuthorization)
// -----------------------------------------------------------------------------

test('Property Authorization: allows new property ID when document does not exist in Firestore', async () => {
  const mockDb = createInMemoryTaskStore({}, {}); // No properties exist
  const ownerId = 'landlord_1';
  const propertyId = 'new_random_prop_id_123';

  const isAllowed = await verifyPropertyUploadAuthorization({
    firestore: mockDb,
    ownerId,
    propertyId,
  });

  assert.equal(isAllowed, true);
});

test('Property Authorization: allows existing property when caller is the owner', async () => {
  const mockDb = createInMemoryTaskStore(
    {},
    {
      existing_prop_1: {
        ownerId: 'landlord_1',
        title: '2BHK in Dhanmondi',
      },
    }
  );

  const isAllowed = await verifyPropertyUploadAuthorization({
    firestore: mockDb,
    ownerId: 'landlord_1',
    propertyId: 'existing_prop_1',
  });

  assert.equal(isAllowed, true);
});

test('Property Authorization: rejects existing property when caller is NOT the owner', async () => {
  const mockDb = createInMemoryTaskStore(
    {},
    {
      victim_prop_1: {
        ownerId: 'legit_owner',
        title: 'Luxury Flat in Gulshan',
      },
    }
  );

  await assert.rejects(
    async () => {
      await verifyPropertyUploadAuthorization({
        firestore: mockDb,
        ownerId: 'malicious_user',
        propertyId: 'victim_prop_1',
      });
    },
    (err) => {
      assert.equal(err.code, 'permission-denied');
      assert.match(err.message, /You do not have permission/);
      return true;
    }
  );
});

test('Property Authorization: rejects path traversal and invalid characters in propertyId', async () => {
  const mockDb = createInMemoryTaskStore();

  await assert.rejects(
    async () => {
      await verifyPropertyUploadAuthorization({
        firestore: mockDb,
        ownerId: 'user1',
        propertyId: '../escape_dir',
      });
    },
    (err) => {
      assert.equal(err.code, 'invalid-argument');
      assert.match(err.message, /Valid propertyId containing only letters/);
      return true;
    }
  );

  await assert.rejects(
    async () => {
      await verifyPropertyUploadAuthorization({
        firestore: mockDb,
        ownerId: 'user1',
        propertyId: 'has/slashes/inside',
      });
    },
    (err) => {
      assert.equal(err.code, 'invalid-argument');
      return true;
    }
  );
});

// -----------------------------------------------------------------------------
// Durable Deletion Regression Tests
// -----------------------------------------------------------------------------

test('Regression 1: deletion-task creation failure fallback via handlePropertyDeletedSnapshot', async () => {
  const mockDb = createInMemoryTaskStore();
  const propertyId = 'prop_recovery_1';
  const propertyData = {
    ownerId: 'landlord_1',
    photos: [
      { storagePath: 'properties/landlord_1/prop_recovery_1/photo_1' },
      { storagePath: 'properties/landlord_1/prop_recovery_1/photo_2' },
    ],
  };

  // Simulate server trigger running when client deleted property without creating tasks
  const result = await handlePropertyDeletedSnapshot({
    firestore: mockDb,
    propertyId,
    propertyData,
  });

  assert.equal(result.queuedCount, 2);
  const task1 = mockDb._store.get('del_prop_recovery_1_properties_landlord_1_prop_recovery_1_photo_1');
  const task2 = mockDb._store.get('del_prop_recovery_1_properties_landlord_1_prop_recovery_1_photo_2');
  assert.ok(task1);
  assert.ok(task2);
  assert.equal(task1.status, 'pending');
  assert.equal(task1.reason, 'property_deleted');
});

test('Regression 2: client disconnect or interruption during deletion completes durably on server', async () => {
  const propertyId = 'prop_interrupted_1';
  const mockDb = createInMemoryTaskStore(
    {},
    {
      [propertyId]: {
        ownerId: 'landlord_1',
        photos: [
          { storagePath: 'properties/landlord_1/prop_interrupted_1/photo_1' },
        ],
      },
    }
  );

  // Client sent delete request, then disconnected. Server completes execution.
  const result = await executeDurablePropertyDeletion({
    firestore: mockDb,
    ownerId: 'landlord_1',
    propertyId,
  });

  assert.equal(result.success, true);
  assert.equal(result.queuedCleanupTasks, 1);
  // Property must be deleted from Firestore
  assert.equal(mockDb._properties.has(propertyId), false);
  // Cleanup task must be durably stored
  const task = mockDb._store.get('del_prop_interrupted_1_properties_landlord_1_prop_interrupted_1_photo_1');
  assert.ok(task);
  assert.equal(task.status, 'pending');
});

test('Regression 3: worker crash after task creation is recovered by lease expiration sweeper', async () => {
  const staleTime = new Date(Date.now() - 30 * 60 * 1000).toISOString(); // Crashed 30 mins ago
  const mockDb = createInMemoryTaskStore({
    task_crashed: {
      _id: 'task_crashed',
      publicId: 'properties/landlord_1/prop1/photo_crashed',
      ownerId: 'landlord_1',
      propertyId: 'prop1',
      status: 'processing',
      retryCount: 1,
      processingStartedAt: staleTime,
    },
  });

  let destroyedPublicId = null;
  const mockCloudinary = {
    uploader: {
      destroy: async (publicId) => {
        destroyedPublicId = publicId;
        return { result: 'ok' };
      },
    },
  };

  const summary = await processPendingMediaCleanupTasks({
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
    limit: 10,
    now: new Date(),
  });

  assert.equal(summary.recoveredStale, 1);
  assert.equal(summary.completed, 1);
  assert.equal(destroyedPublicId, 'properties/landlord_1/prop1/photo_crashed');
  const taskInDb = mockDb._store.get('task_crashed');
  assert.equal(taskInDb.status, 'completed');
  assert.equal(taskInDb.retryCount, 2);
});

test('Regression 4: duplicate deletion requests are safe and idempotent', async () => {
  const propertyId = 'prop_duplicate_1';
  const mockDb = createInMemoryTaskStore(
    {},
    {
      [propertyId]: {
        ownerId: 'landlord_1',
        photos: [{ storagePath: 'properties/landlord_1/prop_duplicate_1/p1' }],
      },
    }
  );

  // First deletion call
  const first = await executeDurablePropertyDeletion({
    firestore: mockDb,
    ownerId: 'landlord_1',
    propertyId,
  });
  assert.equal(first.success, true);
  assert.equal(first.alreadyDeleted, false);
  assert.equal(first.queuedCleanupTasks, 1);

  // Second duplicate deletion call (e.g. user double-clicked or retried)
  const second = await executeDurablePropertyDeletion({
    firestore: mockDb,
    ownerId: 'landlord_1',
    propertyId,
  });
  assert.equal(second.success, true);
  assert.equal(second.alreadyDeleted, true);
  assert.equal(second.queuedCleanupTasks, 0);

  // Duplicate cleanup processing for the same public ID
  const mockCloudinary = {
    uploader: {
      destroy: async () => ({ result: 'not found' }), // Cloudinary reports already removed
    },
  };
  const cleanupResult = await evaluateMediaCleanup({
    task: { publicId: 'properties/landlord_1/prop_duplicate_1/p1', ownerId: 'landlord_1' },
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });
  assert.equal(cleanupResult.action, 'completed');
  assert.equal(cleanupResult.result, 'not found');
});

test('Regression 5: cleanup retry exhaustion permanently halts and dead-letters', async () => {
  const mockDb = createInMemoryTaskStore({
    task_exhausted: {
      publicId: 'properties/landlord_1/prop1/photo_err',
      ownerId: 'landlord_1',
      propertyId: 'prop1',
      status: 'retry_scheduled',
      retryCount: 3, // Already hit MAX_CLEANUP_RETRIES
    },
  });

  const mockCloudinary = {
    uploader: {
      destroy: async () => {
        throw new Error('Cloudinary 500 Persistent Internal Error');
      },
    },
  };

  const result = await processMediaCleanupTask({
    taskId: 'task_exhausted',
    firestore: mockDb,
    cloudinaryClient: mockCloudinary,
  });

  assert.equal(result.status, 'skipped_duplicate_or_terminal');
  const taskInDb = mockDb._store.get('task_exhausted');
  assert.equal(taskInDb.status, 'failed');
  assert.match(taskInDb.error, /Exceeded maximum retry limit/);
  assert.ok(taskInDb.finalizedAt);
});

test('Regression 6: unauthorized user attempting to delete another user property is rejected', async () => {
  const propertyId = 'victim_prop_del';
  const mockDb = createInMemoryTaskStore(
    {},
    {
      [propertyId]: {
        ownerId: 'legit_landlord',
        photos: [{ storagePath: 'properties/legit_landlord/victim_prop_del/p1' }],
      },
    }
  );

  await assert.rejects(
    async () => {
      await executeDurablePropertyDeletion({
        firestore: mockDb,
        ownerId: 'attacker_user',
        propertyId,
      });
    },
    (err) => {
      assert.equal(err.code, 'permission-denied');
      assert.match(err.message, /You do not have permission/);
      return true;
    }
  );

  // Verify property was NOT deleted
  assert.equal(mockDb._properties.has(propertyId), true);
  // Verify no cleanup tasks were queued
  assert.equal(mockDb._store.size, 0);
});

test('Regression 7: handlePropertyDeletedSnapshot preserves existing completed tasks without resetting status or counters', async () => {
  const propertyId = 'prop_preserve_completed';
  const photoPath = 'properties/landlord_1/prop_preserve_completed/photo_1';
  const taskId = 'del_prop_preserve_completed_properties_landlord_1_prop_preserve_completed_photo_1';
  const completedAt = '2026-10-25T10:00:00.000Z';
  const createdAt = '2026-10-25T09:00:00.000Z';
  const updatedAt = '2026-10-25T10:00:00.000Z';

  const mockDb = createInMemoryTaskStore({
    [taskId]: {
      _id: taskId,
      id: taskId,
      publicId: photoPath,
      propertyId,
      ownerId: 'landlord_1',
      status: 'completed',
      retryCount: 2,
      reason: 'property_deleted',
      result: 'ok',
      completedAt,
      createdAt,
      updatedAt,
    },
  });

  const propertyData = {
    ownerId: 'landlord_1',
    photos: [{ storagePath: photoPath }],
  };

  const result = await handlePropertyDeletedSnapshot({
    firestore: mockDb,
    propertyId,
    propertyData,
  });

  assert.equal(result.queuedCount, 0);
  assert.equal(result.preservedCount, 1);
  assert.deepEqual(result.preservedTaskIds, [taskId]);

  const preserved = mockDb._store.get(taskId);
  assert.ok(preserved);
  assert.equal(preserved.status, 'completed');
  assert.equal(preserved.retryCount, 2);
  assert.equal(preserved.result, 'ok');
  assert.equal(preserved.completedAt, completedAt);
  assert.equal(preserved.createdAt, createdAt);
  assert.equal(preserved.updatedAt, updatedAt);
});

test('Regression 8: handlePropertyDeletedSnapshot preserves existing failed tasks and diagnostic history', async () => {
  const propertyId = 'prop_preserve_failed';
  const photoPath = 'properties/landlord_1/prop_preserve_failed/photo_err';
  const taskId = 'del_prop_preserve_failed_properties_landlord_1_prop_preserve_failed_photo_err';
  const finalizedAt = '2026-10-25T12:00:00.000Z';
  const lastAttemptAt = '2026-10-25T12:00:00.000Z';
  const errorMessage = 'Exceeded maximum retry limit of 3 attempts. Error: Cloudinary 500 Persistent Failure';

  const mockDb = createInMemoryTaskStore({
    [taskId]: {
      _id: taskId,
      id: taskId,
      publicId: photoPath,
      propertyId,
      ownerId: 'landlord_1',
      status: 'failed',
      retryCount: 3,
      reason: 'property_deleted',
      error: errorMessage,
      finalizedAt,
      lastAttemptAt,
      createdAt: '2026-10-25T09:00:00.000Z',
      updatedAt: finalizedAt,
    },
  });

  const propertyData = {
    ownerId: 'landlord_1',
    photos: [{ storagePath: photoPath }],
  };

  const result = await handlePropertyDeletedSnapshot({
    firestore: mockDb,
    propertyId,
    propertyData,
  });

  assert.equal(result.queuedCount, 0);
  assert.equal(result.preservedCount, 1);
  assert.deepEqual(result.preservedTaskIds, [taskId]);

  const preserved = mockDb._store.get(taskId);
  assert.ok(preserved);
  assert.equal(preserved.status, 'failed');
  assert.equal(preserved.retryCount, 3);
  assert.equal(preserved.error, errorMessage);
  assert.equal(preserved.finalizedAt, finalizedAt);
  assert.equal(preserved.lastAttemptAt, lastAttemptAt);
});

test('Regression 9: handlePropertyDeletedSnapshot preserves existing pending and processing tasks', async () => {
  const propertyId = 'prop_preserve_active';
  const photoPending = 'properties/landlord_1/prop_preserve_active/photo_pending';
  const photoProcessing = 'properties/landlord_1/prop_preserve_active/photo_proc';
  const taskPendingId = 'del_prop_preserve_active_properties_landlord_1_prop_preserve_active_photo_pending';
  const taskProcessingId = 'del_prop_preserve_active_properties_landlord_1_prop_preserve_active_photo_proc';

  const origCreatedPending = '2026-10-25T08:00:00.000Z';
  const processingStartedAt = '2026-10-25T08:30:00.000Z';

  const mockDb = createInMemoryTaskStore({
    [taskPendingId]: {
      _id: taskPendingId,
      id: taskPendingId,
      publicId: photoPending,
      propertyId,
      ownerId: 'landlord_1',
      status: 'pending',
      retryCount: 0,
      reason: 'property_deleted',
      createdAt: origCreatedPending,
      updatedAt: origCreatedPending,
    },
    [taskProcessingId]: {
      _id: taskProcessingId,
      id: taskProcessingId,
      publicId: photoProcessing,
      propertyId,
      ownerId: 'landlord_1',
      status: 'processing',
      retryCount: 1,
      reason: 'property_deleted',
      processingStartedAt,
      createdAt: '2026-10-25T08:00:00.000Z',
      updatedAt: processingStartedAt,
    },
  });

  const propertyData = {
    ownerId: 'landlord_1',
    photos: [
      { storagePath: photoPending },
      { storagePath: photoProcessing },
    ],
  };

  const result = await handlePropertyDeletedSnapshot({
    firestore: mockDb,
    propertyId,
    propertyData,
  });

  assert.equal(result.queuedCount, 0);
  assert.equal(result.preservedCount, 2);

  const pendingDoc = mockDb._store.get(taskPendingId);
  assert.equal(pendingDoc.status, 'pending');
  assert.equal(pendingDoc.createdAt, origCreatedPending);
  assert.equal(pendingDoc.updatedAt, origCreatedPending); // Did not overwrite timestamps

  const procDoc = mockDb._store.get(taskProcessingId);
  assert.equal(procDoc.status, 'processing');
  assert.equal(procDoc.retryCount, 1);
  assert.equal(procDoc.processingStartedAt, processingStartedAt);
});

test('Regression 10: duplicate trigger invocations are idempotent and preserve existing tasks', async () => {
  const propertyId = 'prop_duplicate_trigger';
  const photo1 = 'properties/landlord_1/prop_duplicate_trigger/photo_1';
  const photo2 = 'properties/landlord_1/prop_duplicate_trigger/photo_2';
  const task1Id = 'del_prop_duplicate_trigger_properties_landlord_1_prop_duplicate_trigger_photo_1';
  const task2Id = 'del_prop_duplicate_trigger_properties_landlord_1_prop_duplicate_trigger_photo_2';

  const mockDb = createInMemoryTaskStore();
  const propertyData = {
    ownerId: 'landlord_1',
    photos: [{ storagePath: photo1 }, { storagePath: photo2 }],
  };

  // First invocation: creates the tasks
  const first = await handlePropertyDeletedSnapshot({
    firestore: mockDb,
    propertyId,
    propertyData,
  });

  assert.equal(first.queuedCount, 2);
  assert.equal(first.preservedCount, 0);

  const task1First = mockDb._store.get(task1Id);
  const task2First = mockDb._store.get(task2Id);
  assert.ok(task1First);
  assert.ok(task2First);
  assert.equal(task1First.status, 'pending');

  // Second duplicate trigger invocation: must NOT recreate or overwrite
  const second = await handlePropertyDeletedSnapshot({
    firestore: mockDb,
    propertyId,
    propertyData,
  });

  assert.equal(second.queuedCount, 0);
  assert.equal(second.preservedCount, 2);
  assert.deepEqual(second.preservedTaskIds.sort(), [task1Id, task2Id].sort());

  const task1Second = mockDb._store.get(task1Id);
  const task2Second = mockDb._store.get(task2Id);
  assert.equal(task1Second.createdAt, task1First.createdAt);
  assert.equal(task1Second.updatedAt, task1First.updatedAt);
  assert.equal(task2Second.createdAt, task2First.createdAt);
  assert.equal(task2Second.updatedAt, task2First.updatedAt);
});

test('Regression 11: concurrent attempts to create the same task serialize atomically without races', async () => {
  const propertyId = 'prop_concurrent_trigger';
  const photo1 = 'properties/landlord_1/prop_concurrent_trigger/photo_1';
  const photo2 = 'properties/landlord_1/prop_concurrent_trigger/photo_2';
  const task1Id = 'del_prop_concurrent_trigger_properties_landlord_1_prop_concurrent_trigger_photo_1';
  const task2Id = 'del_prop_concurrent_trigger_properties_landlord_1_prop_concurrent_trigger_photo_2';

  const mockDb = createInMemoryTaskStore();
  const propertyData = {
    ownerId: 'landlord_1',
    photos: [{ storagePath: photo1 }, { storagePath: photo2 }],
  };

  // Two trigger invocations race at the exact same time
  const [res1, res2] = await Promise.all([
    handlePropertyDeletedSnapshot({
      firestore: mockDb,
      propertyId,
      propertyData,
    }),
    handlePropertyDeletedSnapshot({
      firestore: mockDb,
      propertyId,
      propertyData,
    }),
  ]);

  // Combined across both concurrent calls: exactly 2 created, exactly 2 preserved
  assert.equal(res1.queuedCount + res2.queuedCount, 2);
  assert.equal(res1.preservedCount + res2.preservedCount, 2);

  // Exactly 2 documents exist in Firestore
  assert.equal(mockDb._store.size, 2);
  const doc1 = mockDb._store.get(task1Id);
  const doc2 = mockDb._store.get(task2Id);
  assert.ok(doc1);
  assert.ok(doc2);
  assert.equal(doc1.status, 'pending');
  assert.equal(doc2.status, 'pending');
  assert.equal(doc1.retryCount, 0);
  assert.equal(doc2.retryCount, 0);
});


