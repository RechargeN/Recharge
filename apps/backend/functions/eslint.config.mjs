import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['lib/**', 'node_modules/**'],
  },
  ...tseslint.configs.recommendedTypeChecked,
  {
    files: ['src/**/*.ts', 'test/**/*.ts'],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
    },
  },
);
