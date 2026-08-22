# Particle Monitoring Dashboard

Interactive dashboard and MATLAB analysis for the 2026 CPC/SMPS monitoring campaigns in Rome and Hamburg.

The dashboard combines particle-number concentration, synchronized SMPS size-distribution heatmaps, weather, wind roses, rain, official air-quality observations, and Pearson/Spearman correlation analysis. A dedicated profile tab shows the mean SMPS distribution for the full campaign, each weekday, every hour of day, and eight wind-direction sectors. Use the site selector in the header to switch between Rome and Hamburg.

Hamburg data are enriched with weather from Hamburg-Fuhlsbuettel and air-quality observations from the co-located Sternschanze background station (13ST/DEHH008) plus the nearby Stresemannstrasse traffic station (17SM/DEHH026).

The static GitHub Pages site is generated from `ISPRARomeDisp.m` via `exportWebData.m`. Correlations describe statistical association and do not by themselves identify a causal emission source.
