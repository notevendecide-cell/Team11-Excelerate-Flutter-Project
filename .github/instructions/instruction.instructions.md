---
applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes.

- Always make the best custom pop-up instead of the alert.
- Don't create fixes readme file after the fixing until asked by the user.
[APP_OPTIMIZATION_RULES]
1. The mobile application MUST remain lightweight and optimized.
2. The application MUST NOT contain business logic, authorization rules, or data validation logic.
3. The application MUST act only as a UI and API consumer.
4. All permission checks MUST be handled by the backend, not the app.
5. The application MUST load features lazily (on-demand).
6. No feature, module, or screen should load unless explicitly required by user action.
7. The application MUST minimize API calls and NEVER call multiple APIs unnecessarily.
8. Pagination MUST be enforced for all list-based views.
9. Static data MAY be cached locally; dynamic or sensitive data MUST NOT be cached.
10. The application MUST handle network failures gracefully.
11. The application MUST NOT store secrets, credentials, or private keys.
12. The application MUST rely on token-based authentication only.
13. App size MUST be minimized using tree-shaking, code-splitting, and resource shrinking.
14. The application MUST assume the backend is the single source of truth.
[BACKEND_ARCHITECTURE_RULES]
1. The backend MUST contain all business logic and decision-making processes.
2. Role-Based Access Control (RBAC) MUST be enforced at the backend level.
3. A single API endpoint MAY return different responses based on user roles.
4. The backend MUST validate all inputs regardless of client-side validation.
5. The backend MUST NEVER trust the client.
6. APIs MUST be stateless and token-based.
7. Pagination MUST be mandatory for all list-returning APIs.
8. Heavy tasks (reports, notifications, exports) MUST be handled asynchronously.
9. The backend MUST use caching layers for frequently accessed data.
10. Database calls MUST be optimized and minimized.
11. APIs MUST return only the required fields; SELECT * is strictly prohibited.
12. Rate limiting and request throttling MUST be applied.
13. Error messages MUST be informative but must NOT expose internal system details.
14. The backend MUST be scalable, horizontally and vertically.
[DATABASE_OPTIMIZATION_RULES]
1. The database MUST be treated as a critical and expensive resource.
2. Indexes MUST be created on frequently queried fields.
3. Large datasets MUST ALWAYS be paginated.
4. Joins MUST be optimized and limited.
5. Redundant data MUST be avoided unless required for performance.
6. Read-heavy data SHOULD be cached outside the database.
7. Write operations MUST be atomic and consistent.
8. Transactions MUST be used where data integrity is critical.
9. Background jobs SHOULD handle bulk operations.
10. Database schema changes MUST be backward compatible.
11. The database MUST NOT store unnecessary or duplicate information.
12. Query performance MUST be monitored continuously.
13. Backup and recovery strategies MUST be implemented.
14. The database MUST remain independent of UI or frontend logic.
[WEBSITE_PERFORMANCE_RULES]
1. The website MUST load fast under low-bandwidth conditions.
2. JavaScript bundles MUST be split and loaded on demand.
3. Images MUST be optimized and lazy-loaded.
4. The website MUST NOT perform heavy computation on the client.
5. Server-side rendering SHOULD be used where SEO is important.
6. API calls MUST be minimized and cached when appropriate.
7. UI components MUST be reusable and modular.
8. Authentication and authorization MUST be handled by the backend.
9. The website MUST gracefully handle partial backend failures.
10. Sensitive data MUST NEVER be exposed in the frontend.
11. Forms MUST be validated both client-side and server-side.
12. The website MUST be accessible and responsive.
13. Third-party scripts MUST be minimized.
14. Performance MUST be continuously monitored.
[SYSTEM_GOLDEN_RULE]
The client is temporary.
The backend is authoritative.
The database is sacred.
Performance is a feature.
Security is non-negotiable.
