# Actual contract v2 compatibility pair

Native source revision4e3f90c, iOS26.4.1/build23E254a, iPhone18,1 simulator,
402×874@3x/safe62/34. Native trace is an unmodified copy of accepted trial1
from ios26_4_1_v2_iphone17pro. Candidate trial1 is a fresh runtime capture from
the round1 build; both declare native_contract_version2 and evidence_kindruntime.

All five strict comparison objects (scenario/OS/device/environment/configuration)
match. After explicit approved resolver-probe exclusion, all seven event names
and data objects match. Observed categorical transition sequences also match:
selected medium→large→medium, target medium→large→medium→null, gesture none.

compatibility_report.json records the actual strict analyzer invocation and
SHA256 digests. Numeric/timing verdict is FAIL: event errors61.89–302.35ms,
first-visible error127.00ms, and candidate tail coverage incomplete. No
tolerance was changed and no discrepancy was reclassified as parity. This
one-pair artifact proves the corrected contract boundary only; it cannot
replace repeated native/Flutter physics or holdout acceptance.
