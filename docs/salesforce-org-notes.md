# Gauri SharedDrive Dev — High-Level Notes

**Org:** Gauri SharedDrive Dev  
**Lightning:** https://gaurishareddrive-dev-ed.develop.lightning.force.com/lightning/page/home  
**CLI alias:** `gaurishareddrive`  
**Captured:** 18 Aug 2026 via Tooling API (`ApexClass`, `ApexTrigger`, `ValidationRule`)

This org hosts the **Kosh / Shared Drive** product: external file storage (SharePoint, OneDrive, S3, Azure Blob, Google Drive), document generation (PDF/DOCX), e-signature, archive, and backup/restore.

| Metadata | Count |
|---|---|
| Apex triggers | 6 (all Active) |
| Apex classes | 249 (all Active) — 138 production, 111 test/mock |
| Custom validation rules | **0** |

---

## Triggers

All triggers are **Active**. Production triggers are thin wrappers that delegate to handler classes.

### `ContentDocumentLinkTrigger` — ContentDocumentLink (after insert, API 65.0)

Runs after a file is linked to a record. Calls `ContentDocumentLinkTriggerHandler.handle(Trigger.new)`.

### `ContentVersionTrigger` — ContentVersion (after insert, after update, API 65.0)

Automatically uploads new or updated Salesforce Files to the configured external drive. Calls `ContentVersionTriggerHandler.handle(Trigger.new, Trigger.oldMap)`.

### `DeferredChainSubscriber` — Deferred_Chain__e (after insert, API 62.0)

Platform Event subscriber. When a Queueable cannot chain the next step (governor / Queueable-slot conflicts from other triggers), it publishes `Deferred_Chain__e`. This trigger calls `DeferredChainHandler.handleEvents(Trigger.new)` to enqueue the deferred work in a fresh transaction.

### `LogEventTrigger` — Log_Event__e (after insert, API 66.0)

Persists platform-event log payloads onto `Log__c` (level, message, class, method, stack trace, related record, user, timestamp).

### `MockICRM_CDLTrigger` — ContentDocumentLink (after insert, API 62.0)

**Test-only simulation** of a third-party iCRM ContentDocumentLink trigger. Calls `MockThirdPartyTriggerHandler` so bulk DocGen can be validated against subscriber-org trigger behavior (Tasks / Queueable-slot consumption). Intended for kosh-dev testing.

### `MockRocketphone_TaskTrigger` — Task (after insert, API 62.0)

**Test-only simulation** of `rocketphone.RPTaskTrigger`. Calls `@future` on Task insert, which fails inside batch Apex (`System.AsyncException`). Used to prove deferred Queueable orchestration. Intended for kosh-dev testing.

---

## Apex classes (production, by domain)

Paired `*Test` classes exist for nearly every production class and are omitted from the tables. Names below are the **actual Apex API names** in the org.

### Access, license, and setup

| Class | Role |
|---|---|
| `AccessController` | AccessController Provides @AuraEnabled methods for LWC components to check user access. Combines custom permission checks with license validation so components can gate themselves at render time. Usage from LWC: import c |
| `AdminController` | Shared Drive admin settings CRUD for the admin LWC. |
| `ApiSafetyReserve` | ApiSafetyReserve Prevents Kosh Doc Gen from consuming the last N% of the org's API call and DML limits. Default reserve: 10%. Configurable via Feature Parameter. |
| `HomeController` | Home-page stats for the admin UI. |
| `LicenseGate` | LicenseGate Single enforcement checkpoint called before every document generation operation. Delegates to LicenseManager for Feature Parameter reads, adds seat counting and feature-tier gating. CRITICAL SAFETY CONTRACT:  |
| `LicenseManager` | LicenseManager Manages license validation for Kosh packages using Salesforce Feature Parameters. Feature Parameters are set from the SPP/LMA org and read in subscriber orgs. Feature Parameters used (set via LMA or Featur |
| `OperationsDashboardController` | OperationsDashboardController Provides data for the Operations Dashboard LWC. Shows org info, API usage, job history, error queue, and usage statistics. |
| `SetupWizardController` | SetupWizardController Provides data and actions for the Kosh Doc Gen first-run setup wizard. Handles org registration, initial configuration validation, and setup completion tracking. |
| `SharedDriveSettingsHelper` | Helper class for managing SharedDrive_Settings__c custom settings |

### Shared Drive — file providers and upload

| Class | Role |
|---|---|
| `AwsSignatureV4` | AWS Signature V4 signing for S3 REST calls. |
| `AzureBlobService` | Azure Blob Storage provider implementing IFileProviderService. Uses Azure REST API with Shared Key authorization. Field mapping on SharedDrive_Settings__c: Client_Id__c -> Storage Account Name Client_Secret_Value__c -> S |
| `AzureBlobSignature` | Azure Storage Shared Key authorization signature computation. Produces the Authorization header value for Azure Blob Storage REST API calls. Format: SharedKey {AccountName}:{Base64(HMAC-SHA256(UTF8(StringToSign), Base64D |
| `CircuitBreakerHelper` | Opens the provider circuit after repeated failures. |
| `ContentDocumentLinkTriggerHandler` | Handler for ContentDocumentLinkTrigger; continues upload/linking after a file is linked to a record. |
| `ContentVersionTriggerHandler` | Handler for ContentVersion trigger Processes file uploads to external drives |
| `FileApi` | REST /gsd/v1/files/*. |
| `FileDeleteHelper` | Helper class for file deletion operations |
| `FileIntegrationService` | File Integration Service - Orchestrator for file operations Routes requests to appropriate provider service |
| `FilePreviewController` | Visualforce/page preview of a stored file. |
| `FileTypeValidator` | Enforces allowed file types from settings. |
| `FileUploadHelper` | Retry upload with exponential backoff. |
| `FileUploadQueueable` | Async upload of ContentVersions (one file per transaction). |
| `FolderApi` | REST /gsd/v1/folders/*. |
| `FolderPathResolver` | Resolves {Field} tokens into folder paths. |
| `GoogleDriveService` | Google Drive service implementation Implements IFileProviderService interface Note: This is a skeleton implementation - API integration details need to be completed |
| `HealthApi` | REST /gsd/v1/health. |
| `IFileProviderService` | Interface for file provider services All provider implementations must implement this interface |
| `LinkedFileUploadQueueable` | Async upload for files linked to a specific record. |
| `LiveFileViewController` | Live view of files against a Salesforce record. |
| `OneDriveService` | OneDrive service implementation using Microsoft Graph API Implements IFileProviderService interface Note: Similar to SharePoint but uses user's OneDrive instead of SharePoint site |
| `ProviderFactory` | Returns the IFileProviderService for the configured settings. |
| `RecordFileManagerController` | Per-record file list from SharedDrive_Files__c. |
| `RetryQueueable` | Retries failed uploads from the error queue (one callout+DML per transaction). |
| `S3Service` | Amazon S3 provider (IFileProviderService). |
| `SharedDriveFileViewController` | Lists files in an external folder for the file-browser LWC. |
| `SharePointService` | SharePoint service implementation for Microsoft Graph API Implements IFileProviderService interface |

### Archive and retention

| Class | Role |
|---|---|
| `ArchiveCleanupBatch` | Batch class that purges archives from external storage once they have exceeded the configured retention period (default 7 years). For each expired Archive_Log__c the batch: 1. Lists all files under the external folder pa |
| `ArchiveHelper` | Builds archive folder paths from created date and record Id. |
| `ArchiveNotificationScheduler` | Scheduled class to send archive deletion notifications |
| `ErrorQueueCleanupBatch` | ErrorQueueCleanupBatch Scheduled batch that purges resolved Error_Queue__c records older than the configured retention period. Only deletes entries where Status__c is NOT 'Pending' (i.e. resolved, failed with max retries |
| `FileArchiveBatch` | Batch class for archiving files to external storage. Only processes ContentVersions that have been explicitly flagged Archive_Pending__c = true (set by the Archive Wizard or a bulk admin action). This prevents accidental |
| `FileArchiveController` | Apex controller for file archive operations |
| `LogCleanupBatch` | Purges Log__c past retention. |
| `NotificationHelper` | Sends archive-deletion and similar notifications. |
| `RecordArchiveBatch` | Batch class for archiving records to external drive as JSON files. Safety model: - Per-record success/failure is tracked via Archive_Item__c records. - Records are NEVER deleted automatically. After the batch completes,  |
| `RecordArchiveController` | Apex controller for record archive operations |
| `RecordArchiveHelper` | Helper class for record archiving operations |
| `RecycleBinCleanupBatch` | Empties recycle-bin leftovers. |
| `ScheduledDeleteBatch` | Batch class for scheduled deletion of successfully uploaded files |
| `ScheduledFileDeletion` | Scheduled class to run file deletion at configured time |
| `UsageLogCleanupBatch` | UsageLogCleanupBatch Scheduled batch that purges Usage_Log__c records older than the configured retention period. Reads retention from SharedDrive_Settings__c.Usage_Log_Retention_Months__c (default: 6 months). Run monthl |

### Backup, restore, sandbox seed, and compare

| Class | Role |
|---|---|
| `BackupPolicyController` | AuraEnabled controller for the backupManager LWC. Handles CRUD on Backup_Policy__c, schedule management, manual backup triggers, and snapshot querying. |
| `BackupPolicyScheduler` | Schedulable Apex that runs for a specific Backup_Policy__c. Each policy schedules its own instance using its Schedule_Cron__c expression. On execution: creates a Backup_Snapshot__c (In Progress) and fires BackupSnapshotB |
| `BackupSnapshotBatch` | Core batch for Kosh Backup. Iterates over every SObject type in the policy's Objects_To_Backup__c list. For each type, queries all accessible fields and uploads each record as {StoragePathPrefix}/{SnapshotName}/{ObjectTy |
| `ContentVersionBackupBatch` | Backs up ContentVersion file attachments for all records in a snapshot. Chained from BackupSnapshotBatch.finish() when Include_Files__c = true. Strategy per object type: 1. List the backed-up record JSON files to recover |
| `ContentVersionRestoreQueueable` | Restores ContentVersion file attachments after a record restore completes. Enqueued from RestoreSnapshotBatch.finish() when Restore_Files__c = true on the Restore_Job__c and the snapshot has Files_Backed_Up__c > 0. Strat |
| `CrossOrgRestoreController` | AuraEnabled controller for the crossOrgRestore LWC. Cross-org restore seeds ALL object types from a snapshot into a target org without PII masking (unlike sandbox seeding which supports selective objects + masking). Reus |
| `MetadataBackupJob` | Queueable Apex job that retrieves org metadata via the Metadata API and uploads the resulting ZIP to the configured cloud storage provider. State machine (driven by pollAttempt): pollAttempt == 0 → call retrieve(), captu |
| `MetadataRetrieveHelper` | Builds SOAP envelopes for the Salesforce Metadata API retrieve/checkRetrieveStatus operations and parses their responses. Authentication: Uses a Named Credential named "Kosh_Org_Metadata". The Named Credential must be co |
| `PiiMaskingService` | Applies PII_Mask_Rule__c masking rules to a Map<String, Object> representing a record's field values before seeding to a target org. Mask types: CLEAR → set field to null RANDOM_EMAIL → masked-{hash}@example-kosh.com FAK |
| `RestoreController` | AuraEnabled controller for the restoreWizard LWC. Handles snapshot listing, restore job creation, and progress polling. |
| `RestoreRelationshipMapper` | Maps old Salesforce record IDs → new IDs during a point-in-time restore. During restore, records are re-inserted with new system-assigned IDs. Any lookup/master-detail fields that reference IDs from the backup must be re |
| `RestoreSnapshotBatch` | Restores records from a Backup_Snapshot__c to Salesforce. Restore strategy: 1. Download all JSON files for the object type from S3 (listed via provider.listFiles). 2. Deserialize each JSON file back to a Map<String,Objec |
| `SandboxSeedBatch` | Batch job that seeds data from a Kosh backup snapshot into a target Salesforce org via the target org's REST Composite API. Prerequisites: - A Named Credential (e.g. Kosh_Target_Sandbox) configured with Connected App OAu |
| `SandboxSeedController` | AuraEnabled controller for the sandboxSeed LWC. Manages sandbox seed job creation, PII rule management, and status polling. |
| `SnapshotCompareController` | AuraEnabled controller for the snapshotCompare LWC. Provides snapshot selection, diff job initiation, and status polling. |
| `SnapshotDiffBatch` | Batch job that compares two Kosh backup snapshots and stores a diff result in a Diff_Job__c record. Algorithm (per object type): 1. List files in Snapshot A's storage folder → extract record IDs into Set A 2. List files  |

### Document generation (Kosh Doc Gen)

| Class | Role |
|---|---|
| `DocGenAdminController` | Admin UI for Doc Gen source configs. |
| `DocGenApi` | DocGenApi Clean global utility for programmatic document generation from Apex code. Gated by DocGen_Event_API_Access custom permission (Tier 4 - highest premium). Usage: Map<String, Object> result = DocGenApi.generate(re |
| `DocGenDeliveryService` | DocGenDeliveryService Additive delivery orchestration layer that sits ON TOP of existing PdfGenerationService delivery. Does NOT refactor or replace any existing delivery logic in PdfGenerationService (1,158 lines, 52 te |
| `DocGenInvocable` | DocGenInvocable Invocable Apex action for Flow and trigger-based document generation. Enables Record-Triggered Flows to auto-generate documents when records are created or field values change (e.g., ServiceContract statu |
| `DocGenRecordApi` | DocGenRecordApi REST endpoint for record-based document generation. Gated by DocGen_Event_API_Access custom permission (Tier 4 - highest premium). POST /services/apexrest/gsd/v1/docgen/record { "recordId": "001xx000003AB |
| `DocLifecycleHook` | DocLifecycleHook Global interface that customers implement to inject custom Apex logic at any point in the Kosh document generation pipeline. Registered via Lifecycle_Hook__mdt Custom Metadata Type records. The Lifecycle |
| `DocPacketService` | DocPacketService Generates a "document packet" by running multiple templates against the same record and merging the outputs into a single consolidated PDF. Supports optional PDF security (password protection, permission |
| `DocxToHtmlConverter` | DOCX to HTML conversion for designer/preview. |
| `EmailRecipientResolver` | EmailRecipientResolver Server-side utility to resolve an email address from a record using a dot-notation field path (e.g. "Contact.Email", "Email"). Mirrors the client-side resolveRecipientEmail() in PdfGenerationContro |
| `EmailService` | Sends generated documents by email; suppresses activity logging in batch. |
| `EmailTemplateAdminController` | Design-time admin controller for the Kosh Email Template Manager and Letterhead Manager. Exchanges plain maps with the LWC so the UI never has to deal with the package namespace; the SObjects are built server-side where  |
| `EnricherFieldDescriptor` | Describes an extra merge field contributed by ITemplateDataEnricher. |
| `ExternalPdfService` | Calls the external Kosh PDF microservice (AWS Lambda) to generate pixel-perfect PDFs from DOCX templates via LibreOffice. Lambda API contract: Request: { templateKey: "s3-path", outputKey: "s3-output-path", data: {...} } |
| `HookContext` | HookContext Passed to every DocLifecycleHook invocation. Contains everything the hook needs to make decisions about the current document generation operation. |
| `HookResult` | HookResult Returned by DocLifecycleHook implementations to signal success, skip, or veto. Only BEFORE_* events can veto (cancel) the operation. |
| `ITemplateDataEnricher` | Interface for adding extra merge fields to templates. |
| `JobCallbackApi` | JobCallbackApi REST endpoint for the external orchestrator microservice to request operations that MUST run inside Salesforce context: - Email sending (requires Messaging API, org-wide addresses, templates) - Job complet |
| `LifecycleEngine` | LifecycleEngine Fires lifecycle events at each point in the document generation pipeline. Queries Lifecycle_Hook__mdt for registered hooks, instantiates them via Type.forName(), and calls execute(ctx). PERFORMANCE CONTRA |
| `NoOpDataEnricher` | Minimal {@link ITemplateDataEnricher} for admin validation and template data tests. |
| `PdfApi` | REST POST /gsd/v1/pdf/generate. |
| `PdfGenerationController` | Main UI/Callable entry for single-document PDF generation. |
| `PdfGenerationService` | Core merge + generate + existing delivery path. |
| `RecordDataBuilder` | Builds merge-field maps from a Salesforce record. |
| `TemplateApi` | REST template upload POST /gsd/v1/templates. |
| `TemplateDesignerController` | Loads template content for the designer LWC. |
| `TemplateEngine` | Renders template tokens against merge data (Conga-style loops/conditionals). |
| `TemplateFilterEngine` | Object/field metadata for template filters. |
| `TemplateGovernanceService` | TemplateGovernanceService Manages template versioning, pre-publish validation, and usage tracking for the Kosh Doc Gen template governance framework. |
| `TemplatePromptController` | TemplatePromptController Provides @AuraEnabled methods for LWC components to fetch runtime prompts for a given template and inject prompt responses into merge data. |
| `TemplateRoutingService` | Resolves the email routing context for a record - the localised equivalent of the Conga record formula fields (Conga_Template__c -> CongaEmailTemplateGroup, Conga_Default_Email_Template__c -> CongaEmailTemplateId, Conga_ |
| `UsageMeter` | UsageMeter Logs document generation operations to Usage_Log__c for metering, analytics, and partner-side billing visibility. All logging is asynchronous (Queueable) to avoid DML overhead in the generation pipeline. If th |
| `WordAddinApi` | REST for the Word add-in (/gsd/v1/addin/*). |

### Bulk and scheduled generation

| Class | Role |
|---|---|
| `AutomationController` | Lists and manages scheduled jobs in the Automation tab. |
| `BulkDocGenInvocable` | Invocable Apex entry point for launching Kosh Bulk Doc Gen jobs from Flows. Designed for Screen Flows used as list-view mass actions. Accepts selected record IDs plus a full set of job configuration options, then delegat |
| `BulkDownloadPackageQueueable` | Packages bulk-generated PDF blobs for browser download only. Does not attach files to source records — stores a single transient ContentVersion on the bulk job (Generated_File_Ids__c) for auto-download. Individual output |
| `BulkIndividualZipQueueable` | Builds a single ZIP from all individually generated PDFs on a bulk job. Used when Output_Mode__c = Individual so users download one archive instead of many separate PDFs. |
| `BulkJobDeferredOrchestratorQueueable` | Orchestrates deferred batch operations in a clean Queueable context. After BulkPdfGenerationBatch.finish(), this Queueable runs operations that were collected during execute() but deferred to avoid @future conflicts from |
| `BulkLaunchGate` | Access control gate for bulk document generation launched from list views. Provides both an @InvocableMethod for Flows and @AuraEnabled for LWC. Configuration (allowed profiles, list views, record limit) is passed as par |
| `BulkListLaunchPendingService` | Stores pending bulk-launch requests so a utility-bar host can open a modal over the list view after the VF bridge page redirects back to Lightning. Uses Platform Cache because VF (vf.force.com) and Lightning (lightning.f |
| `BulkListLaunchRedirectController` | VF bridge for bulk list-view mass actions. Reads a Bulk_Launch_Config__mdt record by DeveloperName (from the ?config= URL param) to resolve template, source config, gate rules, and delivery presets. |
| `BulkPdfGenerationBatch` | Batch generate PDFs across selected records. |
| `BulkPdfGenerationController` | UI controller to launch and monitor bulk PDF jobs. |
| `ConsolidatedPdfQueueable` | Queueable job that merges individual PDFs into a consolidated document after a bulk batch completes. Enqueued from BulkPdfGenerationBatch.finish() because finish() cannot make HTTP callouts directly. |
| `ConsolidatedPdfService` | ConsolidatedPdfService Merges multiple individual PDFs into a single consolidated document. Calls the Lambda /merge-bundle endpoint to combine PDF blobs. Used at the end of bulk jobs when Output_Mode__c = 'Consolidated'. |
| `DeferredActivityQueueable` | Executes activity (Task) logging in a separate Queueable transaction. When batch Apex creates Tasks, third-party triggers (e.g. rocketphone.RPTaskTrigger) fire @future methods, which are prohibited inside batch context.  |
| `DeferredChainHandler` | Handles Deferred_Chain__e Platform Events to continue Queueable chains that were interrupted by governor limits. When DeferredStorageDeliveryQueueable or DeferredPostUpdateQueueable cannot enqueue the next step (because  |
| `DeferredPostUpdateQueueable` | Executes post-generation field updates in a separate Queueable transaction. When third-party managed packages consume governor limits (e.g. @future calls) during a batch lifecycle, downstream automation triggered by fiel |
| `DeferredStorageDeliveryQueueable` | Executes file delivery (Content Library or Attach to Record) in a separate Queueable transaction. When ContentVersion inserts trigger third-party managed package code that makes @future calls (e.g. iCRM -> rocketphone),  |
| `ProcessingEngine` | ProcessingEngine Continuous Processing Engine that runs on a configurable interval (default: 1 minute) to pick up and process Scheduled_Job__c records in ContinuousEngine mode. Unlike Time-Based scheduling which creates  |
| `ScheduleManager` | ScheduleManager CRUD operations for Scheduled_Job__c records. Handles creating, activating, deactivating, and deleting scheduled jobs. For Time-Based mode, manages Salesforce CronTrigger scheduling. For Continuous Engine |
| `ScheduledJobApi` | ScheduledJobApi REST endpoint for external polling microservice integration. Provides three operations: GET /gsd/v1/scheduled-jobs/due — returns jobs due to run now POST /gsd/v1/scheduled-jobs/trigger — triggers a specif |
| `ScheduledJobExecutor` | ScheduledJobExecutor Implements Schedulable to execute Time-Based scheduled document generation. Each Scheduled_Job__c record in Time-Based mode gets its own CronTrigger that invokes this class. On execute: queries for r |
| `ScheduledJobLaunchHelper` | Shared helpers for scheduled job launch paths (TimeBased, ProcessingEngine, REST API). Ensures consistent record counting and avoids launching bulk jobs when nothing matches. |
| `ScheduledJobTemplateResolver` | ScheduledJobTemplateResolver Shared helper used by ScheduledJobExecutor (TimeBased) and ProcessingEngine (ContinuousEngine) to resolve ordered template IDs based on Template_Output__c mode. Single mode: returns the job's |

### E-signature

| Class | Role |
|---|---|
| `DocumentFieldService` | Saves/loads e-sign document fields. |
| `EnvelopeEmailService` | Sends e-sign envelope signing-request emails. |
| `EnvelopeScheduler` | Schedulable/batch for envelope reminders and expiry. |
| `EnvelopeService` | Envelope lifecycle (Callable) for e-sign. |
| `EnvelopeSigningController` | Guest signing-page controller for envelopes. |
| `ESignEnvelopeApi` | REST /gsd/v1/envelope/*. |
| `ESignIntegrationBridge` | Callable bridge so other packages can invoke e-sign. |
| `ESignatureApi` | REST /gsd/v1/esign/*. |
| `ESignatureService` | Core e-sign ceremony logic. |
| `RecipientService` | E-sign recipient order and related operations. |
| `SignatureAuditService` | Immutable audit trail and audit certificate generation for e-signature ceremonies. |
| `SignatureCryptoService` | SHA-256 hashing for e-signature document integrity. |
| `SignatureEmailService` | Signing-request emails for GSD_Signature_Request__c. |
| `SignatureTokenService` | Secure signing-link tokens for GSD_Signature_Request__c. |
| `SigningTemplateService` | Save envelope as a reusable signing template. |

### Logging and test support

| Class | Role |
|---|---|
| `MockThirdPartyTriggerHandler` | Simulates third-party trigger behavior found on client QAS org: - iCRM_ContentDocumentLinkTrigger: creates a Task when CDL is inserted - rocketphone.RPTaskTrigger: calls @future when Task is inserted Controlled by static |
| `SharedDriveLogger` | Logging framework for SharedDrive operations Provides centralized logging functionality |

---

## Full production class list (138)

`AccessController`, `AdminController`, `ApiSafetyReserve`, `ArchiveCleanupBatch`, `ArchiveHelper`, `ArchiveNotificationScheduler`, `AutomationController`, `AwsSignatureV4`, `AzureBlobService`, `AzureBlobSignature`, `BackupPolicyController`, `BackupPolicyScheduler`, `BackupSnapshotBatch`, `BulkDocGenInvocable`, `BulkDownloadPackageQueueable`, `BulkIndividualZipQueueable`, `BulkJobDeferredOrchestratorQueueable`, `BulkLaunchGate`, `BulkListLaunchPendingService`, `BulkListLaunchRedirectController`, `BulkPdfGenerationBatch`, `BulkPdfGenerationController`, `CircuitBreakerHelper`, `ConsolidatedPdfQueueable`, `ConsolidatedPdfService`, `ContentDocumentLinkTriggerHandler`, `ContentVersionBackupBatch`, `ContentVersionRestoreQueueable`, `ContentVersionTriggerHandler`, `CrossOrgRestoreController`, `DeferredActivityQueueable`, `DeferredChainHandler`, `DeferredPostUpdateQueueable`, `DeferredStorageDeliveryQueueable`, `DocGenAdminController`, `DocGenApi`, `DocGenDeliveryService`, `DocGenInvocable`, `DocGenRecordApi`, `DocLifecycleHook`, `DocPacketService`, `DocumentFieldService`, `DocxToHtmlConverter`, `EmailRecipientResolver`, `EmailService`, `EmailTemplateAdminController`, `EnricherFieldDescriptor`, `EnvelopeEmailService`, `EnvelopeScheduler`, `EnvelopeService`, `EnvelopeSigningController`, `ErrorQueueCleanupBatch`, `ESignatureApi`, `ESignatureService`, `ESignEnvelopeApi`, `ESignIntegrationBridge`, `ExternalPdfService`, `FileApi`, `FileArchiveBatch`, `FileArchiveController`, `FileDeleteHelper`, `FileIntegrationService`, `FilePreviewController`, `FileTypeValidator`, `FileUploadHelper`, `FileUploadQueueable`, `FolderApi`, `FolderPathResolver`, `GoogleDriveService`, `HealthApi`, `HomeController`, `HookContext`, `HookResult`, `IFileProviderService`, `ITemplateDataEnricher`, `JobCallbackApi`, `LicenseGate`, `LicenseManager`, `LifecycleEngine`, `LinkedFileUploadQueueable`, `LiveFileViewController`, `LogCleanupBatch`, `MetadataBackupJob`, `MetadataRetrieveHelper`, `MockThirdPartyTriggerHandler`, `NoOpDataEnricher`, `NotificationHelper`, `OneDriveService`, `OperationsDashboardController`, `PdfApi`, `PdfGenerationController`, `PdfGenerationService`, `PiiMaskingService`, `ProcessingEngine`, `ProviderFactory`, `RecipientService`, `RecordArchiveBatch`, `RecordArchiveController`, `RecordArchiveHelper`, `RecordDataBuilder`, `RecordFileManagerController`, `RecycleBinCleanupBatch`, `RestoreController`, `RestoreRelationshipMapper`, `RestoreSnapshotBatch`, `RetryQueueable`, `S3Service`, `SandboxSeedBatch`, `SandboxSeedController`, `ScheduledDeleteBatch`, `ScheduledFileDeletion`, `ScheduledJobApi`, `ScheduledJobExecutor`, `ScheduledJobLaunchHelper`, `ScheduledJobTemplateResolver`, `ScheduleManager`, `SetupWizardController`, `SharedDriveFileViewController`, `SharedDriveLogger`, `SharedDriveSettingsHelper`, `SharePointService`, `SignatureAuditService`, `SignatureCryptoService`, `SignatureEmailService`, `SignatureTokenService`, `SigningTemplateService`, `SnapshotCompareController`, `SnapshotDiffBatch`, `TemplateApi`, `TemplateDesignerController`, `TemplateEngine`, `TemplateFilterEngine`, `TemplateGovernanceService`, `TemplatePromptController`, `TemplateRoutingService`, `UsageLogCleanupBatch`, `UsageMeter`, `WordAddinApi`

---

## Validation rules

**No custom validation rules** are present in this org.

- Tooling API `ValidationRule` query returned 0 records.
- Metadata API `listMetadata` for type `ValidationRule` returned none.

If rules are added later, they will appear in Setup → Object Manager → [Object] → Validation Rules, and as `objects/<Object>/validationRules/*.xml` in source.

---

## Suggested reading order

1. Triggers + handlers: `ContentVersionTrigger` → `ContentVersionTriggerHandler` → `FileIntegrationService` → provider (`SharePointService` / `S3Service` / …).
2. Single Doc Gen: `PdfGenerationController` → `PdfGenerationService` → `ExternalPdfService`.
3. Bulk Doc Gen: `BulkPdfGenerationController` → `BulkPdfGenerationBatch` → deferred Queueables.
4. Backup: `BackupPolicyController` → `BackupSnapshotBatch` → `RestoreSnapshotBatch`.
