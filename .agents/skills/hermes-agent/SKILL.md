```markdown
# hermes-agent Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development conventions and workflows used in the `hermes-agent` repository, a TypeScript codebase with no detected framework. You'll learn how to structure files, write imports and exports, follow commit message guidelines, and organize tests. This guide is ideal for contributors aiming for consistency and maintainability in the project.

## Coding Conventions

### File Naming
- **Pattern:** PascalCase for all files.
- **Example:**  
  ```
  HermesAgent.ts
  MessageHandler.ts
  ```

### Import Style
- **Pattern:** Use relative imports for all internal modules.
- **Example:**
  ```typescript
  import { MessageHandler } from './MessageHandler';
  ```

### Export Style
- **Pattern:** Use named exports exclusively.
- **Example:**
  ```typescript
  // In HermesAgent.ts
  export function startAgent() { ... }
  ```

### Commit Messages
- **Pattern:** Conventional commit format.
- **Prefixes:** `chore`, `docs`
- **Example:**
  ```
  chore: update dependencies
  docs: add usage instructions
  ```

## Workflows

### Commit Changes
**Trigger:** When making any change to the codebase  
**Command:** `/commit-changes`

1. Make your code or documentation changes.
2. Stage your changes:  
   ```
   git add .
   ```
3. Write a commit message using the conventional format (e.g., `chore: update dependencies`).
4. Commit your changes:  
   ```
   git commit -m "chore: update dependencies"
   ```
5. Push to your branch:  
   ```
   git push
   ```

### Add or Update Documentation
**Trigger:** When adding or updating documentation files  
**Command:** `/update-docs`

1. Edit or create documentation files as needed.
2. Stage your changes:  
   ```
   git add .
   ```
3. Commit with a `docs:` prefix:  
   ```
   git commit -m "docs: improve API documentation"
   ```
4. Push your changes:  
   ```
   git push
   ```

## Testing Patterns

- **Test File Pattern:** All test files follow the `*.test.*` naming convention.
  - **Example:**  
    ```
    HermesAgent.test.ts
    ```
- **Testing Framework:** Not explicitly detected; refer to project documentation or package.json for specifics.
- **Test Structure:** Place tests alongside or near the files they test, using the `.test.ts` suffix.

## Commands
| Command           | Purpose                                      |
|-------------------|----------------------------------------------|
| /commit-changes   | Guide for making code or doc commits         |
| /update-docs      | Steps for updating documentation             |
```
