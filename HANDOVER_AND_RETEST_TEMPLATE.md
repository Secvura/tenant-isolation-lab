# Remediation handover and retest record (template)

Free to use and adapt. It records what was fixed and how each fix was checked. It is not a certification, and a passed retest covers only the check described, on the build named.

| Field | What to record |
|---|---|
| Finding ID | The reference in the original report (for example "F-03") |
| Source report | Who wrote it, and its title and date |
| Finding title | As written in the report |
| Agreed scope | Exactly what will be fixed, and what will not |
| Fix prepared | Short description of the change, with a link to the pull request or commit |
| Status | One of: fix prepared / deployment pending / deployed / retested / accepted risk |
| Deployed build | Commit hash or release tag, and the environment |
| Retest procedure | The exact steps or test file, including at least one allowed case and one blocked case |
| Retest result | Pass or fail for each step, with the date and the person who ran it |
| Evidence | Test output or screenshots, with secrets and personal data removed |
| Limits | What this retest does not show |
| Outstanding actions | Anything left, its owner and its date |
| Original tester's retest | Needed? Yes or no. If yes, when it is booked |
