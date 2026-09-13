"""Export presentation-ready SVG time-series figures for the four campaigns."""
import json
from pathlib import Path
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
OUT = ROOT / "figures"
OUT.mkdir(exist_ok=True)
SITES = [("bologna", "Bologna"), ("rome", "ISPRA (Rome)"), ("hoheduene", "Hohe Düne"), ("hamburg", "Hamburg")]
COLORS = ["#d75446", "#3277b8", "#176b55", "#e49242", "#7d5ba6"]

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 14, "axes.titlesize": 20, "axes.labelsize": 17, "xtick.labelsize": 13, "ytick.labelsize": 13, "legend.fontsize": 13, "svg.fonttype": "none"})

def load(slug):
    with (DATA_DIR / f"{slug}-monitoring.json").open(encoding="utf-8") as f: return json.load(f)

def arr(values): return np.array([np.nan if x is None else float(x) for x in values], dtype=float)

def raw(times, y, flags=None):
    """Return every original measurement timestamp/value (no averaging)."""
    t = np.array([np.datetime64(x) for x in times]).astype("datetime64[ns]")
    if flags is not None:
        y = y.copy(); y[np.array(flags) == 1] = np.nan
    return t.astype("datetime64[s]"), y

def label_key(key):
    return {"CPC": "CPC total", "SMPSTotal": "SMPS total", "GeometricMeanDiameter": "SMPS GMD", "CPC3789": "CPC 3789", "CPC3783": "CPC 3783", "CPC3750": "CPC 3750", "Partector": "Partector"}.get(key, key)

def save(fig, name):
    fig.tight_layout(pad=1.3); fig.savefig(OUT / name, transparent=True, bbox_inches="tight"); plt.close(fig)

def dense_date_axis(ax):
    locator = mdates.AutoDateLocator(minticks=8, maxticks=16, interval_multiples=True)
    ax.xaxis.set_major_locator(locator)
    ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(locator))

# Normalized comparison across all four requested locations.
fig, ax = plt.subplots(figsize=(13.333, 6.7), dpi=160); fig.patch.set_alpha(0); ax.set_facecolor("none")
for i, (slug, site_name) in enumerate(SITES):
    d = load(slug); keys = d["site"].get("primaryKeys") or (["CPC", "SMPSTotal"] if "CPC" in d["series"] else ["SMPSTotal"])
    y = arr(d["series"][keys[0]]); t, y = raw(d["time"], y, d["series"].get("OutlierFlag")); mu, sd = np.nanmean(y), np.nanstd(y)
    ax.plot(t, (y - mu) / sd if sd else y * np.nan, lw=1.8, color=COLORS[i], label=site_name)
ax.set_title("Total concentration time series — all sites"); ax.set_ylabel("Standardized concentration (z-score)"); ax.set_xlabel("Date")
ax.grid(True, color="#e6ebe7", alpha=1, lw=.8); ax.spines[["top", "right"]].set_visible(False); ax.legend(loc="upper left", frameon=False, ncol=4)
dense_date_axis(ax); save(fig, "all-sites-overview-timeseries.svg")

# One readable figure for each requested location.
for slug, site_name in SITES:
    d = load(slug); s = d["series"]; flags = s.get("OutlierFlag")
    keys = d["site"].get("primaryKeys") or (["CPC", "SMPSTotal"] if "CPC" in s else ["SMPSTotal"])
    if len(keys) == 1 and keys[0] == "SMPSTotal" and "GeometricMeanDiameter" in s: keys = ["SMPSTotal", "GeometricMeanDiameter"]
    fig, ax = plt.subplots(figsize=(13.333, 6.7), dpi=160); fig.patch.set_alpha(0); ax.set_facecolor("none"); ax2 = None
    for i, key in enumerate(keys[:5]):
        t, y = raw(d["time"], arr(s[key]), flags); target = ax
        if key == "GeometricMeanDiameter":
            ax2 = ax.twinx(); ax2.set_facecolor("none"); ax2.spines[["top", "left"]].set_visible(False); target = ax2
        target.plot(t, y, lw=1.8, color=COLORS[i], label=label_key(key))
    ax.set_title(f"{site_name} — total concentration time series"); ax.set_ylabel("Particle number concentration [cm$^{-3}$]"); ax.set_xlabel("Date")
    if ax2 is not None: ax2.set_ylabel("Geometric mean diameter [nm]")
    ax.grid(True, color="#e6ebe7", alpha=1, lw=.8); ax.spines[["top", "right"]].set_visible(False)
    handles, names = ax.get_legend_handles_labels()
    if ax2 is not None: h2, n2 = ax2.get_legend_handles_labels(); handles += h2; names += n2
    ax.legend(handles, names, loc="upper left", frameon=False, ncol=min(4, len(names))); dense_date_axis(ax)
    save(fig, f"{slug}-overview-timeseries.svg")

# Additional Hamburg figure containing only the SMPS total concentration.
d = load("hamburg"); s = d["series"]
t, y = raw(d["time"], arr(s["SMPSTotal"]), s.get("OutlierFlag"))
fig, ax = plt.subplots(figsize=(13.333, 6.7), dpi=160); fig.patch.set_alpha(0); ax.set_facecolor("none")
ax.plot(t, y, lw=1.8, color="#3277b8", label="SMPS total")
ax.set_title("Hamburg — SMPS total concentration time series")
ax.set_ylabel("Particle number concentration [cm$^{-3}$]"); ax.set_xlabel("Date")
ax.grid(True, color="#e6ebe7", alpha=1, lw=.8); ax.spines[["top", "right"]].set_visible(False)
ax.legend(loc="upper left", frameon=False); dense_date_axis(ax)
save(fig, "hamburg-smps-overview-timeseries.svg")

print("Wrote six SVG time-series figures to", OUT)
