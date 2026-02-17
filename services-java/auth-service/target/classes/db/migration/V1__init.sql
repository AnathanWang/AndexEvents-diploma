-- Auth-service schema baseline.
-- Auth-service is a stateless JWT validation gateway.
-- It reads user data from users."User" (managed by users-service).
-- This migration ensures the 'auth' schema and Flyway history exist.

-- Grant read access on users schema (if exists) so auth-service
-- can look up users by Firebase UID for JWT → internal-ID mapping.
GRANT USAGE ON SCHEMA users TO CURRENT_USER;
