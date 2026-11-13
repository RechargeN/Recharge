import type { Firestore } from 'firebase-admin/firestore';
import {
  applyOwnerSafety,
  type SafetyInstruction,
  type SafetyInstructionVerifier,
} from '../../../shared/safety_instruction.js';
export const applyCatalogSafety = (
  db: Firestore,
  verifier: SafetyInstructionVerifier,
  input: SafetyInstruction,
) => applyOwnerSafety(db, 'catalog', verifier, input);
