# Particle Monitoring Dashboard

Interactive dashboard for the particle-monitoring campaigns in Rome, Hamburg, and Rostock-Hohe Düne (2025/2026).

The dashboard combines particle-number concentration, synchronized SMPS size-distribution heatmaps where available, weather, wind roses, rain, official air-quality observations, ship passages, and Pearson/Spearman correlation analysis. A dedicated profile tab shows selectable SMPS bar profiles with 95% confidence intervals for Rome and Hamburg. Use the site selector in the header to switch between all three campaigns.

The animated map includes an optional near-surface backward-advection cloud. Its direction and extent follow the station wind; its shading follows CPC concentration. Individually selectable, color-coded pollutant clouds use the same exploratory treatment for nearby air-quality observations. These are possible-origin corridors, not trajectory models or source proof.

Hamburg data are enriched with weather from Hamburg-Fuhlsbuettel and air-quality observations from the co-located Sternschanze background station (13ST/DEHH008) plus the nearby Stresemannstrasse traffic station (17SM/DEHH026).

Hohe Düne contains no SMPS measurements. Its four particle series are TSI 3789 water CPC, TSI 3783 water CPC, TSI 3750 butanol CPC, and Partector. Ship-passage timestamps are shown alongside weather from the campaign coordinates and official PM10, PM2.5, NO2, and SO2 observations from the co-located Rostock-Hohe Düne station (DEMV031).

The static GitHub Pages site is generated from `ISPRARomeDisp.m` via `exportWebData.m`. Correlations describe statistical association and do not by themselves identify a causal emission source.
