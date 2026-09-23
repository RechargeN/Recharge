import type { PlatformConfigBundle } from '../../config/load_config.js';
import type { Authorizer } from '../../security/authorizer.js';
import type { AppCheckPort } from '../../security/app_check_port.js';
import type { RateLimitPort } from '../../security/rate_limit_port.js';
import type { SecurityAuditPort } from '../../security/security_audit_port.js';
import type { DeepReadonly } from '../../shared/immutable.js';
import type { ConfigService } from '../config/config_service.js';
import type { ReferenceDataService } from '../../modules/reference_data/application/reference_data_service.js';
import type { PrivacyOrchestrationService } from '../../modules/privacy_orchestration/application/privacy_orchestration_service.js';
import type { IdentityPublisherAuthority } from '../../modules/identity_publisher/application/identity_publisher_authority.js';
import type { IdentityAuthorityRepository } from '../../modules/identity_publisher/domain/repositories.js';
import type {
  PrivacyRequestRepository,
  PrivacyTaskRepository,
} from '../../modules/privacy_orchestration/domain/repositories.js';
import type { AuthenticationGuardPort } from '../../security/authentication_guard.js';
import type { AgePolicyPort } from '../../security/age_policy_port.js';
import type { CollectionAccessMatrix } from '../../security/collection_access_matrix.js';
import type { DataClassRegistry } from '../../security/data_class_registry.js';
import type { RetentionRegistry } from '../../security/retention_registry.js';
import type { FeatureFlagRepository } from '../config/feature_flag_repository.js';
import type { MarketConfigRepository } from '../config/market_config_repository.js';
import type { MetricsPort } from '../observability/metrics.js';
import type { StructuredLogger } from '../observability/structured_logger.js';
import type { RollbackGuard } from '../recovery/rollback_guard.js';
import type { ReleaseManifestRepository } from '../release/release_manifest_repository.js';
import type { ReleaseService } from '../release/release_service.js';

export interface InternalApiRegistry {
  readonly schemaIds: readonly string[];
  readonly commandHandlers: readonly never[];
  readonly queryHandlers: readonly never[];
  readonly workers: readonly never[];
  readonly schedules: readonly never[];
}

export interface PlatformApp {
  readonly config: DeepReadonly<PlatformConfigBundle>;
  readonly apiRegistry: InternalApiRegistry;
  readonly services: {
    readonly config: ConfigService;
    readonly referenceData: ReferenceDataService;
    readonly privacy: PrivacyOrchestrationService;
    readonly identityPublisher: IdentityPublisherAuthority;
    readonly release: ReleaseService;
    readonly rollback: RollbackGuard;
  };
  readonly repositories: {
    readonly featureFlags: FeatureFlagRepository;
    readonly marketConfigs: MarketConfigRepository;
    readonly releaseManifests: ReleaseManifestRepository;
    readonly privacyRequests: PrivacyRequestRepository;
    readonly privacyTasks: PrivacyTaskRepository;
    readonly identityAuthority: IdentityAuthorityRepository;
  };
  readonly security: {
    readonly authorizer: Authorizer;
    readonly authentication: AuthenticationGuardPort;
    readonly appCheck: AppCheckPort;
    readonly agePolicy: AgePolicyPort;
    readonly rateLimit: RateLimitPort;
    readonly audit: SecurityAuditPort;
    readonly dataClasses: DataClassRegistry;
    readonly collectionAccess: CollectionAccessMatrix;
    readonly retention: RetentionRegistry;
  };
  readonly observability: {
    readonly logger: StructuredLogger;
    readonly metrics: MetricsPort;
  };
}
