## Exposure Mapping

Replaces the prior heuristic "reachability" model. Goal: stop trying to PROVE a vuln is unreachable — false negatives are dangerous. Instead, enumerate every import site of the target package and bucket each one. The user makes the final risk call from the surface area.
