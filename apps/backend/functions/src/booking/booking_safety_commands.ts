import type { Firestore } from 'firebase-admin/firestore';
import {
  applyOwnerSafety,
  type SafetyInstruction,
  type SafetyInstructionVerifier,
} from '../shared/safety_instruction.js';
/** Does not mutate existing bookings, inventory or cancellation/refund state. */
export const applyBookingSafety = (
  db: Firestore,
  verifier: SafetyInstructionVerifier,
  input: SafetyInstruction,
) => applyOwnerSafety(db, 'booking', verifier, input);
