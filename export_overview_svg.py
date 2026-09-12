"""Export presentation-ready SVG figures from the Bologna dashboard data."""
import json
from pathlib import Path

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data" / "bologna-monitoring.json"
OUT = ROOT / "figures"
OUT.mkdir(exist_ok=True)

with DATA.open(encoding="utf-8") as f:
    d = json.load(f)

times = np.array([np.datetime64(x) for x in d["time"]])
series = d["series"]
outliers = np.array(series.get("OutlierFlag", [0] * len(times))) == 1

def values(key):
    return np.array([np.nan if x is None else float(x) for x in series[key]], dtype=float)

def daily_mean(y):
    days = times.astype("datetime64[D]")
    unique = np.unique(days)
    result = []
    for day in unique:
        mask = days == day
        finite = np.isfinite(y[mask])
        result.append(np.nanmean(y[mask]) if finite.any() else np.nan)
    return unique.astype("datetime64[ns]").astype("datetime64[s]"), np.array(result)

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 10, "axes.titlesize": 16,
    "axes.labelsize": 11, "legend.fontsize": 10, "svg.fonttype": "none",
})

# Figure 1: daily overview over the complete campaign period.
primary = "CPC" if "CPC" in series else "SMPSTotal"
secondary = "SMPSTotal" if primary == "CPC" else "GeometricMeanDiameter"
primary_label = "CPC total concentration" if primary == "CPC" else "SMPS total concentration"
secondary_label = "SMPS total concentration" if primary == "CPC" else "SMPS geometric mean diameter"
a = values(primary); b = values(secondary)
a[outliers] = np.nan; b[outliers] = np.nan
td, a_d = daily_mean(a)
_, b_d = daily_mean(b)
fig, ax = plt.subplots(figsize=(13.333, 5.6), dpi=160)
fig.patch.set_alpha(0)
ax.set_facecolor("none")
ax.plot(td, a_d, color="#c94f4f", lw=1.35, label=primary_label)
if secondary == "GeometricMeanDiameter":
    ax2 = ax.twinx(); ax2.set_facecolor("none")
    ax2.plot(td, b_d, color="#2776b8", lw=1.35, label=secondary_label)
    ax2.set_ylabel("Geometric mean diameter [nm]")
    ax2.spines[["top", "left"]].set_visible(False)
else:
    ax.plot(td, b_d, color="#2776b8", lw=1.35, label=secondary_label)
ax.set_title("Bologna SMPS overview — complete campaign")
ax.set_ylabel("Number concentration [cm$^{-3}$]")
ax.set_xlabel("Date (daily means; outlier hours excluded)")
ax.grid(True, color="#9aa6ad", alpha=0.24, lw=0.7)
ax.spines[["top", "right"]].set_visible(False)
handles, labels_ = ax.get_legend_handles_labels()
if secondary == "GeometricMeanDiameter":
    h2, l2 = ax2.get_legend_handles_labels(); handles += h2; labels_ += l2
ax.legend(handles, labels_, loc="upper left", frameon=False, ncol=2)
ax.xaxis.set_major_locator(mdates.MonthLocator(interval=6))
ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
fig.autofmt_xdate(rotation=0, ha="center")
fig.tight_layout(pad=1.1)
fig.savefig(OUT / "bologna-overview-timeseries.svg", transparent=True, bbox_inches="tight")
plt.close(fig)

# Figure 2: paired hourly correlation, with a linear fit.
x = values(primary)
y = values(secondary)
valid = np.isfinite(x) & np.isfinite(y) & ~outliers
x, y = x[valid], y[valid]
pearson = float(np.corrcoef(x, y)[0, 1])
spearman = float(np.corrcoef(np.argsort(np.argsort(x)), np.argsort(np.argsort(y)))[0, 1])
fit = np.polyfit(x, y, 1)
xx = np.linspace(np.nanpercentile(x, 0.5), np.nanpercentile(x, 99.5), 200)
fig, ax = plt.subplots(figsize=(8.4, 6.1), dpi=160)
fig.patch.set_alpha(0)
ax.set_facecolor("none")
# Keep the SVG lightweight while retaining the full-sample statistics.
step = max(1, len(x) // 3500)
ax.scatter(x[::step], y[::step], s=7, alpha=0.2, color="#2b7f72", linewidths=0)
ax.plot(xx, fit[0] * xx + fit[1], color="#b34ead", lw=2.1, label="Linear fit")
ax.set_title(f"{primary_label} vs {secondary_label}")
ax.set_xlabel(primary_label + (" [cm$^{-3}$]" if primary == "CPC" else " [cm$^{-3}$]"))
ax.set_ylabel(secondary_label + (" [cm$^{-3}$]" if secondary == "SMPSTotal" else " [nm]"))
ax.grid(True, color="#9aa6ad", alpha=0.24, lw=0.7)
ax.spines[["top", "right"]].set_visible(False)
ax.legend(loc="upper left", frameon=False)
ax.text(0.99, 0.03, f"n = {len(x):,}\nPearson r = {pearson:.3f}\nSpearman ρ = {spearman:.3f}",
        transform=ax.transAxes, ha="right", va="bottom", fontsize=10,
        bbox={"boxstyle": "round,pad=0.35", "facecolor": "white", "edgecolor": "#c9d1d5", "alpha": 0.82})
fig.tight_layout(pad=1.1)
fig.savefig(OUT / "bologna-cpc-smps-correlation.svg", transparent=True, bbox_inches="tight")
plt.close(fig)

print(f"Wrote {OUT / 'bologna-overview-timeseries.svg'}")
print(f"Wrote {OUT / 'bologna-cpc-smps-correlation.svg'}")
