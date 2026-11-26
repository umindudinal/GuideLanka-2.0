const assert = require('assert');
const path = require('path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-key';
process.env.SUPABASE_URL = process.env.SUPABASE_URL || 'https://example.supabase.co';
process.env.SUPABASE_KEY = process.env.SUPABASE_KEY || 'test-key';

// Stub supabaseClient in require cache so tests run offline without touching production data
const supabasePath = require.resolve(path.join(__dirname, '../src/config/supabaseClient.js'));
const mockQuery = {
  select: () => mockQuery,
  insert: () => mockQuery,
  update: () => mockQuery,
  upsert: () => mockQuery,
  delete: () => mockQuery,
  eq: () => mockQuery,
  neq: () => mockQuery,
  in: () => mockQuery,
  gte: () => mockQuery,
  match: () => mockQuery,
  order: () => mockQuery,
  limit: () => mockQuery,
  single: async () => ({ data: null, error: { message: 'Not found' } }),
  maybeSingle: async () => ({ data: null, error: null }),
  then: (resolve) => resolve({ data: [], error: null }),
};
require.cache[supabasePath] = {
  id: supabasePath,
  filename: supabasePath,
  loaded: true,
  exports: { from: () => mockQuery },
};

const authController = require('../src/controllers/authController');
const bookingController = require('../src/controllers/bookingController');
const sightingController = require('../src/controllers/sightingController');
const alertController = require('../src/controllers/alertController');
const routeController = require('../src/controllers/routeController');
const driverController = require('../src/controllers/driverController');
const chatController = require('../src/controllers/chatController');
const authMiddleware = require('../src/middlewares/authMiddleware');
const authorizeRoles = require('../src/middlewares/roleMiddleware');

function makeRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    send(payload) {
      this.body = payload;
      return this;
    },
  };
}

async function runTests() {
  const tests = [];
  const test = (name, fn) => tests.push({ name, fn });

  // Middleware & RBAC
  test('authMiddleware rejects missing Authorization header (401)', () => {
    const res = makeRes();
    let nextCalled = false;
    authMiddleware({ header: () => null }, res, () => { nextCalled = true; });
    assert.strictEqual(nextCalled, false);
    assert.strictEqual(res.statusCode, 401);
  });

  test('authMiddleware rejects invalid JWT token (403)', () => {
    const res = makeRes();
    let nextCalled = false;
    authMiddleware({ header: () => 'Bearer invalid.jwt.token' }, res, () => { nextCalled = true; });
    assert.strictEqual(nextCalled, false);
    assert.strictEqual(res.statusCode, 403);
  });

  test('authorizeRoles blocks TOURIST from DRIVER/AUTHORITY routes (403)', () => {
    const res = makeRes();
    let nextCalled = false;
    authorizeRoles('AUTHORITY', 'ADMIN')({ user: { id: '1', role: 'TOURIST' } }, res, () => { nextCalled = true; });
    assert.strictEqual(nextCalled, false);
    assert.strictEqual(res.statusCode, 403);
  });

  // Auth validation
  test('registerUser rejects missing required fields (400)', async () => {
    const res = makeRes();
    await authController.registerUser({ body: {} }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  test('registerUser rejects weak password (400)', async () => {
    const res = makeRes();
    await authController.registerUser({
      body: { full_name: 'Test', email: 't@example.com', password: '123', role: 'TOURIST' },
    }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  test('loginUser rejects missing email/password (400)', async () => {
    const res = makeRes();
    await authController.loginUser({ body: {} }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  test('changePassword rejects weak password and cross-user override (400/403)', async () => {
    const resWeak = makeRes();
    await authController.changePassword({
      user: { id: 'u1' },
      body: { user_id: 'u1', old_password: 'Old', new_password: 'weak' },
    }, resWeak);
    assert.strictEqual(resWeak.statusCode, 400);

    const resCross = makeRes();
    await authController.changePassword({
      user: { id: 'u1' },
      body: { user_id: 'u2', old_password: 'Old', new_password: 'Strong!Password1' },
    }, resCross);
    assert.strictEqual(resCross.statusCode, 403);
  });

  test('registerAuthority rejects missing fields (400)', async () => {
    const res = makeRes();
    await authController.registerAuthority({ body: {} }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  // Booking validation
  test('createBooking rejects missing/invalid booking_date and past dates (400)', async () => {
    const resMissing = makeRes();
    await bookingController.createBooking({ user: { id: 'u1' }, body: { driver_id: 'd1' } }, resMissing);
    assert.strictEqual(resMissing.statusCode, 400);

    const resPast = makeRes();
    await bookingController.createBooking({ user: { id: 'u1' }, body: { driver_id: 'd1', booking_date: '2020-01-01' } }, resPast);
    assert.strictEqual(resPast.statusCode, 400);
  });

  test('createBooking rejects negative or zero tourist_count (400)', async () => {
    const res = makeRes();
    await bookingController.createBooking({
      user: { id: 'u1' },
      body: { driver_id: 'd1', booking_date: '2099-12-31', tourist_count: -3 },
    }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  test('updateBookingStatus rejects missing or invalid status (400)', async () => {
    const resMissing = makeRes();
    await bookingController.updateBookingStatus({ params: { id: 'b1' }, user: { id: 'd1' }, body: {} }, resMissing);
    assert.strictEqual(resMissing.statusCode, 400);

    const resInvalid = makeRes();
    await bookingController.updateBookingStatus({ params: { id: 'b1' }, user: { id: 'd1' }, body: { status: 'BOGUS' } }, resInvalid);
    assert.strictEqual(resInvalid.statusCode, 400);
  });

  // Sighting, Alert, Route validation
  test('logSighting rejects missing fields (400)', async () => {
    const res = makeRes();
    await sightingController.logSighting({ body: { driver_id: 'd1' } }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  test('receiveAlert & createSOSAlert reject missing fields (400)', async () => {
    const res1 = makeRes();
    await alertController.receiveAlert({ body: { driver_id: 'd1' } }, res1);
    assert.strictEqual(res1.statusCode, 400);

    const res2 = makeRes();
    await alertController.createSOSAlert({ body: { driver_id: 'd1' } }, res2);
    assert.strictEqual(res2.statusCode, 400);
  });

  test('calculateBestRoute rejects empty routes (400)', async () => {
    const res = makeRes();
    await routeController.calculateBestRoute({ body: { currentLat: 6.5, currentLng: 81.3, availableRoutes: [] } }, res);
    assert.strictEqual(res.statusCode, 400);
  });

  // Driver profile & review validation
  test('updateDriverProfile rejects non-positive price and negative experience (400)', async () => {
    const resPrice = makeRes();
    await driverController.updateDriverProfile({
      user: { id: 'd1' },
      body: { name: 'Driver', pricePerSafari: -500 },
    }, resPrice);
    assert.strictEqual(resPrice.statusCode, 400);

    const resExp = makeRes();
    await driverController.updateDriverProfile({
      user: { id: 'd1' },
      body: { name: 'Driver', pricePerSafari: 12000, experienceYears: -2 },
    }, resExp);
    assert.strictEqual(resExp.statusCode, 400);
  });

  test('addDriverReview rejects missing comment or out-of-range rating (400)', async () => {
    const resEmpty = makeRes();
    await driverController.addDriverReview({ params: { driverId: 'd1' }, body: { rating: 5, comment: '   ' } }, resEmpty);
    assert.strictEqual(resEmpty.statusCode, 400);

    const resRange = makeRes();
    await driverController.addDriverReview({ params: { driverId: 'd1' }, body: { rating: 99, comment: 'Great' } }, resRange);
    assert.strictEqual(resRange.statusCode, 400);
  });

  // Chat validation
  test('sendMessage rejects empty text or missing sender_id (400)', async () => {
    const resEmpty = makeRes();
    await chatController.sendMessage({ body: { booking_id: 'b1', text: '   ', sender_id: 'u1' } }, resEmpty);
    assert.strictEqual(resEmpty.statusCode, 400);

    const resSender = makeRes();
    await chatController.sendMessage({ body: { booking_id: 'b1', text: 'Hello' } }, resSender);
    assert.strictEqual(resSender.statusCode, 400);
  });

  let passed = 0;
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      passed++;
      console.log(`PASS: ${t.name}`);
    } catch (err) {
      failed++;
      console.error(`FAIL: ${t.name} -> ${err.message}`);
    }
  }
  console.log(`\nValidation Test Summary: ${passed} passed, ${failed} failed`);
  process.exitCode = failed > 0 ? 1 : 0;
}

runTests();
