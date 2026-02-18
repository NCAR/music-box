import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ConditionsManager } from '../../src/conditions_manager.js';

describe('ConditionsManager constructor', () => {
  it('uses default temperature and pressure when no data provided', () => {
    const mgr = new ConditionsManager([]);
    const conds = mgr.getConditionsAtTime(0);
    assert.equal(conds.temperature, 298.15);
    assert.equal(conds.pressure, 101325.0);
  });

  it('reads temperature and pressure from a data row', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0, 'ENV.temperature.K': 217.6, 'ENV.pressure.Pa': 1394.3 },
    ]);
    const conds = mgr.getConditionsAtTime(0);
    assert.equal(conds.temperature, 217.6);
    assert.equal(conds.pressure, 1394.3);
  });

  it('stores CONC.* columns as concentration events at their exact time', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6, 'CONC.O2.mol m-3': 0.162 },
    ]);
    assert.equal(mgr.concentrationEvents[0]['O3'], 6.43e-6);
    assert.equal(mgr.concentrationEvents[0]['O2'], 0.162);
  });

  it('concentration events do not appear in getConditionsAtTime', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6 },
    ]);
    const conds = mgr.getConditionsAtTime(0);
    assert.ok(!('concentrations' in conds), 'concentrations should not be in returned object');
    assert.ok(!('O3' in conds), 'species should not be in returned object');
  });

  it('accepts null or empty input gracefully', () => {
    const mgr1 = new ConditionsManager(null);
    const mgr2 = new ConditionsManager([]);
    assert.equal(mgr1.getConditionsAtTime(0).temperature, 298.15);
    assert.equal(mgr2.getConditionsAtTime(0).temperature, 298.15);
    assert.deepEqual(mgr1.concentrationEvents, {});
  });

  it('CONC.* at different times stored as separate events', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0,    'CONC.O3.mol m-3': 6.43e-6 },
      { 'time.s': 3600, 'CONC.O3.mol m-3': 5.00e-6 },
    ]);
    assert.equal(mgr.concentrationEvents[0]['O3'], 6.43e-6);
    assert.equal(mgr.concentrationEvents[3600]['O3'], 5.00e-6);
  });
});

describe('ConditionsManager.getConditionsAtTime - step interpolation', () => {
  it('returns defaults before any time points', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 3600, 'ENV.temperature.K': 250.0 },
    ]);
    const conds = mgr.getConditionsAtTime(0);
    assert.equal(conds.temperature, 298.15);
  });

  it('applies row values at exact time', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 3600, 'ENV.temperature.K': 250.0 },
    ]);
    assert.equal(mgr.getConditionsAtTime(3600).temperature, 250.0);
  });

  it('holds value after last time point (step interpolation)', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0,    'ENV.temperature.K': 220.0 },
      { 'time.s': 3600, 'ENV.temperature.K': 240.0 },
    ]);
    assert.equal(mgr.getConditionsAtTime(1800).temperature, 220.0);
    assert.equal(mgr.getConditionsAtTime(3600).temperature, 240.0);
    assert.equal(mgr.getConditionsAtTime(7200).temperature, 240.0);
  });

  it('accumulates rate params from earlier time points', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0,    'PHOTO.O2_1.s-1': 1.47e-12, 'PHOTO.O3_1.s-1': 4.25e-5 },
      { 'time.s': 3600, 'PHOTO.O2_1.s-1': 1.12e-13 },
    ]);
    const conds0 = mgr.getConditionsAtTime(0);
    assert.equal(conds0.rateParams['PHOTO.O2_1'], 1.47e-12);
    assert.equal(conds0.rateParams['PHOTO.O3_1'], 4.25e-5);

    // At t=3600: O2_1 updated, O3_1 inherited from t=0
    const conds1 = mgr.getConditionsAtTime(3600);
    assert.equal(conds1.rateParams['PHOTO.O2_1'], 1.12e-13);
    assert.equal(conds1.rateParams['PHOTO.O3_1'], 4.25e-5);
  });

  it('strips unit suffix from rate param keys', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0, 'PHOTO.O2_1.s-1': 1.47e-12, 'EMIS.NO.mol m-3 s-1': 0.001 },
    ]);
    const conds = mgr.getConditionsAtTime(0);
    assert.ok('PHOTO.O2_1' in conds.rateParams);
    assert.ok('EMIS.NO' in conds.rateParams);
    assert.ok(!('PHOTO.O2_1.s-1' in conds.rateParams));
  });

  it('throws on a malformed rate parameter key with no dot-separated name', () => {
    assert.throws(
      () => new ConditionsManager([{ 'time.s': 0, 'PHOTO': 1.47e-12 }]),
      /Malformed rate parameter key "PHOTO"/
    );
  });

  it('handles empty data array', () => {
    const mgr = new ConditionsManager([]);
    assert.equal(mgr.getConditionsAtTime(9999).temperature, 298.15);
    assert.deepEqual(mgr.getConditionsAtTime(9999).rateParams, {});
  });

  it('sorts unsorted rows by time', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 3600, 'ENV.temperature.K': 250.0 },
      { 'time.s': 0,    'ENV.temperature.K': 200.0 },
    ]);
    assert.equal(mgr.getConditionsAtTime(0).temperature, 200.0);
    assert.equal(mgr.getConditionsAtTime(3600).temperature, 250.0);
  });

  it('row with mixed CONC and ENV columns: ENV is interpolated, CONC is event', () => {
    const mgr = new ConditionsManager([
      { 'time.s': 0, 'ENV.temperature.K': 217.6, 'CONC.O3.mol m-3': 6.43e-6 },
    ]);
    // Temperature is interpolated
    assert.equal(mgr.getConditionsAtTime(0).temperature, 217.6);
    assert.equal(mgr.getConditionsAtTime(9999).temperature, 217.6);
    // Concentration is a separate event, not in getConditionsAtTime result
    assert.equal(mgr.concentrationEvents[0]['O3'], 6.43e-6);
  });
});
