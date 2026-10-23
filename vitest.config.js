import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['rules_tests/**/*.test.js'],
    testTimeout: 15000,
    hookTimeout: 15000,
  },
});

