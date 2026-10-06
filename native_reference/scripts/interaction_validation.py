"""Actual delivery/outcome controls; alpha is never an interaction observation."""

def nonmodal_outcomes(rows):
    probes = []
    current = None
    for row in rows:
        if row.get("type") != "event": continue
        name, data = row.get("name"), row.get("data", {})
        if name == "background.probe.requested":
            if current is not None: raise ValueError("Unclosed background probe")
            current = {"phase": data["phase"], "before": data["activation_before"], "touches": 0}
        elif name == "input.touch" and current is not None:
            current["touches"] += 1
        elif name == "background.probe.completed":
            if current is None or current["phase"] != data["phase"]: raise ValueError("Probe boundary mismatch")
            delivery = data.get("delivered_target_touch_events")
            if type(delivery) is not int or delivery <= 0 or current["touches"] == 0:
                raise ValueError("No actual delivered touch in requested background region")
            delta = data["activation_after"] - current["before"]
            if delta not in (0,1): raise ValueError("Ambiguous activation delta")
            probes.append({"phase": current["phase"], "activated": delta == 1, "delivered_touch_events": delivery})
            current = None
    if current is not None or not probes: raise ValueError("Missing complete actual touch probes")
    return probes
