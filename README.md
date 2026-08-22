# Particle Monitoring Dashboard

Interactive dashboard and MATLAB analysis for the 2026 CPC/SMPS monitoring campaigns in Rome and Hamburg.

The dashboard combines particle-number concentration, synchronized SMPS size-distribution heatmaps, weather, wind roses, rain, official air-quality observations, and Pearson/Spearman correlation analysis. A dedicated profile tab shows selectable SMPS bar profiles for any date range, weekday, hour of day, and eight wind-direction sectors. The overview compares hourly CPC and SMPS total concentrations directly. Use the site selector in the header to switch between Rome and Hamburg.

The animated map includes an optional near-surface backward-advection cloud. Its direction and extent follow the station wind; its shading follows CPC concentration. This is an exploratory possible-origin corridor, not a trajectory model or source proof.

Hamburg data are enriched with weather from Hamburg-Fuhlsbuettel and air-quality observations from the co-located Sternschanze background station (13ST/DEHH008) plus the nearby Stresemannstrasse traffic station (17SM/DEHH026).

The static GitHub Pages site is generated from `ISPRARomeDisp.m` via `exportWebData.m`. Correlations describe statistical association and do not by themselves identify a causal emission source.
