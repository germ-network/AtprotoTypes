---
"@germ-network/atprototypes": minor
---

`PutRecordOutput.commit`, `PutRecordOutput.validationStatus` and `DeleteRecordOutput.commit` are now optional, so a PDS no-op (identical record, or deleting a missing record) decodes. `PutRecordOutput.ValidationStatus` is now an open `RawRepresentable` struct with `.valid` and `.unknown`, so unrecognized values decode instead of throwing.
