#!/usr/bin/env python3
"""Explicit mathematical diagnostics; fit quality does not identify Apple physics."""
import json
import math
import statistics
import sys

from compare import TraceError, finite, require, rms


def pairs(x, y):
    require(isinstance(x, list) and isinstance(y, list) and len(x) == len(y) and len(x) >= 2,
            "paired finite samples required")
    require(all(finite(v) for v in x + y), "nonfinite sample")


def linear(x, y):
    pairs(x, y)
    mx, my = statistics.fmean(x), statistics.fmean(y)
    denominator = sum((v - mx) ** 2 for v in x)
    require(denominator > 0, "unidentifiable constant input")
    gain = sum((a - mx) * (b - my) for a, b in zip(x, y)) / denominator
    intercept = my - gain * mx
    errors = [gain * a + intercept - b for a, b in zip(x, y)]
    return {"gain": gain, "intercept": intercept, "rms": rms(errors), "max": max(abs(v) for v in errors),
            "formula": "sheet_displacement = intercept + gain * finger_displacement"}


def spring(request):
    times, values = request["times_s"], request["values"]
    pairs(times, values)
    require(len(times) >= 8 and times[0] == 0 and all(times[i] > times[i - 1] for i in range(1, len(times))),
            "at least 8 increasing event-relative samples starting at zero required")
    target = request["target"]
    require(finite(target), "observed target required")
    omegas, zetas = request["omega_candidates"], request["zeta_candidates"]
    require(omegas and zetas and len(omegas) * len(zetas) <= 100_000, "bounded explicit search grid required")
    require(all(finite(w) and w > 0 for w in omegas) and all(finite(z) and 0 <= z < 1 for z in zetas),
            "only underdamped candidate grids supported; never force critical/overdamped motion into this model")
    residual = [value - target for value in values]
    ranked = []
    for omega in omegas:
        for zeta in zetas:
            decay, wd = omega * zeta, omega * math.sqrt(1 - zeta * zeta)
            cosine = [math.exp(-decay * t) * math.cos(wd * t) for t in times]
            sine = [math.exp(-decay * t) * math.sin(wd * t) for t in times]
            aa, ab, bb = sum(v * v for v in cosine), sum(a * b for a, b in zip(cosine, sine)), sum(v * v for v in sine)
            ay, by = sum(a * b for a, b in zip(cosine, residual)), sum(a * b for a, b in zip(sine, residual))
            det = aa * bb - ab * ab
            if det <= 1e-14:
                continue
            a, b = (ay * bb - by * ab) / det, (by * aa - ay * ab) / det
            errors = [a * c + b * s - y for c, s, y in zip(cosine, sine, residual)]
            ranked.append({"omega_n": omega, "zeta": zeta, "omega_d": wd, "decay_rate": decay,
                           "A": a, "B": b, "initial_velocity": b * wd - decay * a,
                           "response_period_s": 2 * math.pi / omega,
                           "unit_mass_equivalent": {"stiffness": omega * omega, "damping": 2 * zeta * omega},
                           "rms": rms(errors), "max": max(abs(v) for v in errors)})
    require(ranked, "unidentifiable spring basis")
    ranked.sort(key=lambda result: result["rms"])
    best = ranked[0]
    best["runner_up_rms"] = ranked[1]["rms"] if len(ranked) > 1 else None
    best["search_grid"] = {"omega_count": len(omegas), "zeta_count": len(zetas), "omega_range": [min(omegas), max(omegas)], "zeta_range": [min(zetas), max(zetas)]}
    best["formula"] = "x(t)=target+exp(-zeta*omega_n*t)*(A*cos(omega_d*t)+B*sin(omega_d*t))"
    best["limitations"] = ["grid fit is conditional on selected model and target", "no mass identification", "no parameter confidence interval without repeated runtime trials", "piecewise, nonlinear or critically damped motion may need another model"]
    return best


def fit(request):
    try:
        require(isinstance(request, dict), "request must be an object")
        require(request.get("evidence_kind") in ("runtime", "synthetic"), "explicit evidence kind required")
        model = request.get("model")
        if model == "linear_transfer":
            result = linear(request["finger_displacement"], request["sheet_displacement"])
        elif model == "underdamped_spring":
            result = spring(request)
        else:
            raise TraceError("unsupported model; unresolved")
        return {"status": "fit_only", "model": model, "proof_scope": "synthetic_math_only" if request["evidence_kind"] == "synthetic" else "conditional_runtime_fit", **result}
    except (TraceError, KeyError, TypeError, ValueError) as error:
        return {"status": "unresolved", "issues": [str(error)]}


if __name__ == "__main__":
    try:
        result = fit(json.load(sys.stdin))
    except json.JSONDecodeError as error:
        result = {"status": "unresolved", "issues": [str(error)]}
    print(json.dumps(result, allow_nan=False, indent=2))
    sys.exit(1 if result["status"] == "unresolved" else 0)
