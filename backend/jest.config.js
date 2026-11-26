module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.js'],
  globalSetup: '<rootDir>/tests/setup/globalMongo.js',
  globalTeardown: '<rootDir>/tests/setup/globalMongoTeardown.js',
  testTimeout: 30000,
  collectCoverageFrom: ['src/**/*.js'],
  coverageDirectory: 'coverage',
  verbose: true,
};
