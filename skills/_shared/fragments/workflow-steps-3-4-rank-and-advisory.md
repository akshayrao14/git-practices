3. **Rank** using the prioritization framework (Impact × Exposure × CVSS).
4. **Read advisory** for the top pick — extract `first_patched_version`, `vulnerable_version_range`, and `cvss.score`. For clusters, compute the *minimal* version that supersets every CVE patch.
