import { loadPlatformConfig, type PlatformConfigBundle } from '../../config/load_config.js';
import { platformTargetRefs } from '../../contracts/schema_registry.js';
import { referenceDataTargetRefs } from '../../contracts/reference_data_schema_registry.js';
import { privacyTargetRefs } from '../../contracts/privacy_schema_registry.js';
import { identityTargetRefs } from '../../contracts/identity_schema_registry.js';
import { createLocalIdentityPublisherAuthority } from '../../modules/identity_publisher/application/identity_publisher_authority.js';
import { PrivacyOrchestrationService } from '../../modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { InMemoryPrivacyRequestRepository } from '../../modules/privacy_orchestration/infrastructure/in_memory_privacy_request_repository.js';
import { InMemoryPrivacyTaskRepository } from '../../modules/privacy_orchestration/infrastructure/in_memory_privacy_task_repository.js';
import { LocalUnavailableAgePolicyPort } from '../../security/age_policy_port.js';
import { LocalDenyAuthenticationGuard } from '../../security/authentication_guard.js';
import { securityPrivacyCollectionAccess } from '../../security/collection_access_matrix.js';
import { DataClassRegistry } from '../../security/data_class_registry.js';
import { RetentionRegistry } from '../../security/retention_registry.js';
import { ReferenceDataService } from '../../modules/reference_data/application/reference_data_service.js';
import { LocalDenyAppCheckPort } from '../../security/app_check_port.js';
import { DefaultDenyAuthorizer } from '../../security/default_deny_authorizer.js';
import { LocalDenyRateLimitPort } from '../../security/rate_limit_port.js';
import { InMemorySecurityAuditPort } from '../../security/security_audit_port.js';
import { ConfigService } from '../config/config_service.js';
import { InMemoryFeatureFlagRepository } from '../config/feature_flag_repository.js';
import { InMemoryMarketConfigRepository } from '../config/market_config_repository.js';
import { InMemoryMetricsPort } from '../observability/metrics.js';
import { InMemoryStructuredLogger } from '../observability/structured_logger.js';
import { RollbackGuard } from '../recovery/rollback_guard.js';
import { InMemoryReleaseManifestRepository } from '../release/release_manifest_repository.js';
import { ReleaseService } from '../release/release_service.js';
import type { PlatformApp } from './app.js';

export function createLocalPlatformApp(bundle: PlatformConfigBundle): PlatformApp {
  const config = loadPlatformConfig(bundle);
  const featureFlags = new InMemoryFeatureFlagRepository();
  const marketConfigs = new InMemoryMarketConfigRepository();
  const releaseManifests = new InMemoryReleaseManifestRepository();
  const privacyRequests = new InMemoryPrivacyRequestRepository();
  const privacyTasks = new InMemoryPrivacyTaskRepository();
  const identity = createLocalIdentityPublisherAuthority();
  const dataClasses = new DataClassRegistry([
    {
      dataClassId: 'privacy.request',
      classification: 'sensitive',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'privacy.request',
    },
    {
      dataClassId: 'identity.account',
      classification: 'personal',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'identity.account',
    },
    {
      dataClassId: 'identity.provider-link',
      classification: 'restricted',
      containsDirectIdentifiers: false,
      containsSecrets: false,
      exportEligible: false,
      deletionEligible: true,
      retentionPolicyId: 'identity.provider-link',
    },
    {
      dataClassId: 'identity.session',
      classification: 'restricted',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'identity.session',
    },
    {
      dataClassId: 'identity.access-snapshot',
      classification: 'restricted',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'identity.access-snapshot',
    },
    {
      dataClassId: 'identity.creator-verification',
      classification: 'sensitive',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'identity.creator-verification',
    },
    {
      dataClassId: 'identity.managed-page',
      classification: 'personal',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'identity.managed-page',
    },
    {
      dataClassId: 'identity.page-membership',
      classification: 'personal',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: true,
      deletionEligible: true,
      retentionPolicyId: 'identity.page-membership',
    },
    {
      dataClassId: 'privacy.task',
      classification: 'sensitive',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: false,
      deletionEligible: true,
      retentionPolicyId: 'privacy.task',
    },
    {
      dataClassId: 'security.audit',
      classification: 'restricted',
      containsDirectIdentifiers: false,
      containsSecrets: false,
      exportEligible: false,
      deletionEligible: false,
      retentionPolicyId: 'security.audit',
    },
    {
      dataClassId: 'booking.idempotency',
      classification: 'restricted',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: false,
      deletionEligible: true,
      retentionPolicyId: 'booking.idempotency.retry-window',
    },
    {
      dataClassId: 'booking.outbox',
      classification: 'restricted',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: false,
      deletionEligible: true,
      retentionPolicyId: 'booking.outbox.delivery-reconciliation',
    },
    {
      dataClassId: 'booking.audit',
      classification: 'restricted',
      containsDirectIdentifiers: true,
      containsSecrets: false,
      exportEligible: false,
      deletionEligible: false,
      retentionPolicyId: 'booking.audit.legal-security',
    },
  ]);
  const retention = new RetentionRegistry([
    { policyId: 'privacy.request', status: 'unresolved', legalHoldSupported: true },
    { policyId: 'privacy.task', status: 'unresolved', legalHoldSupported: true },
    { policyId: 'security.audit', status: 'unresolved', legalHoldSupported: true },
    { policyId: 'identity.account', status: 'unresolved', legalHoldSupported: true },
    { policyId: 'identity.provider-link', status: 'unresolved', legalHoldSupported: true },
    { policyId: 'identity.session', status: 'unresolved', legalHoldSupported: true },
    {
      policyId: 'identity.access-snapshot',
      status: 'unresolved',
      legalHoldSupported: true,
    },
    {
      policyId: 'identity.creator-verification',
      status: 'unresolved',
      legalHoldSupported: true,
    },
    { policyId: 'identity.managed-page', status: 'unresolved', legalHoldSupported: true },
    { policyId: 'identity.page-membership', status: 'unresolved', legalHoldSupported: true },
    {
      policyId: 'booking.idempotency.retry-window',
      status: 'unresolved',
      legalHoldSupported: true,
    },
    {
      policyId: 'booking.outbox.delivery-reconciliation',
      status: 'unresolved',
      legalHoldSupported: true,
    },
    {
      policyId: 'booking.audit.legal-security',
      status: 'unresolved',
      legalHoldSupported: true,
    },
  ]);

  return Object.freeze({
    config,
    apiRegistry: Object.freeze({
      schemaIds: Object.freeze(
        [
          ...new Set(
            [
              ...Object.values(platformTargetRefs),
              ...Object.values(referenceDataTargetRefs),
              ...Object.values(privacyTargetRefs),
              ...Object.values(identityTargetRefs),
            ].map((reference) => reference.replace(/#.*/u, '')),
          ),
        ].sort(),
      ),
      commandHandlers: Object.freeze([]),
      queryHandlers: Object.freeze([]),
      workers: Object.freeze([]),
      schedules: Object.freeze([]),
    }),
    services: Object.freeze({
      config: new ConfigService(featureFlags),
      referenceData: new ReferenceDataService(marketConfigs),
      privacy: new PrivacyOrchestrationService(privacyRequests, privacyTasks),
      identityPublisher: identity.authority,
      release: new ReleaseService(releaseManifests),
      rollback: new RollbackGuard(releaseManifests),
    }),
    repositories: Object.freeze({
      featureFlags,
      marketConfigs,
      releaseManifests,
      privacyRequests,
      privacyTasks,
      identityAuthority: identity.repository,
    }),
    security: Object.freeze({
      authorizer: new DefaultDenyAuthorizer(),
      authentication: new LocalDenyAuthenticationGuard(),
      appCheck: new LocalDenyAppCheckPort(),
      agePolicy: new LocalUnavailableAgePolicyPort(),
      rateLimit: new LocalDenyRateLimitPort(),
      audit: new InMemorySecurityAuditPort(),
      dataClasses,
      collectionAccess: securityPrivacyCollectionAccess,
      retention,
    }),
    observability: Object.freeze({
      logger: new InMemoryStructuredLogger(),
      metrics: new InMemoryMetricsPort(),
    }),
  });
}
