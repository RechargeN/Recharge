import type { Firestore } from 'firebase-admin/firestore';

import {
  marketConfigRevisionCollection,
  referenceActivationPointerCollection,
} from '../config/market_config_repository.js';
import { featureFlagRevisionCollection } from '../config/feature_flag_repository.js';
import {
  activeReleasePointerCollection,
  releaseManifestCollection,
} from '../release/release_manifest_repository.js';

export class FirestoreConfigReader {
  constructor(private readonly firestore: Firestore) {}

  async readActiveReleasePointer(
    documentId: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    return this.readDocument(activeReleasePointerCollection, documentId);
  }

  async readActiveReferencePointer(
    documentId: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    return this.readDocument(referenceActivationPointerCollection, documentId);
  }

  async readReleaseManifest(documentId: string): Promise<Readonly<Record<string, unknown>> | null> {
    return this.readDocument(releaseManifestCollection, documentId);
  }

  async readMarketConfigRevision(
    documentId: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    return this.readDocument(marketConfigRevisionCollection, documentId);
  }

  async readFeatureFlagRevision(
    documentId: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    return this.readDocument(featureFlagRevisionCollection, documentId);
  }

  private async readDocument(
    collection: string,
    documentId: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    if (!/^[A-Za-z0-9._:-]{1,256}$/.test(documentId)) {
      throw new TypeError('firestore_document_id_invalid');
    }
    const snapshot = await this.firestore.collection(collection).doc(documentId).get();
    return snapshot.exists ? Object.freeze({ ...(snapshot.data() ?? {}) }) : null;
  }
}
