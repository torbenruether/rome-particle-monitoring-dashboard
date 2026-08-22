function exportWebData(cpc,smps,sizes,weather,airQuality,site,file)
% Exportiert die MATLAB-Auswertung kompakt fuer das statische Web-Dashboard.
metrics=computeSMPSMetrics(smps,sizes);
C=retime(cpc(:,{'Concentration'}),'regular','mean','TimeStep',minutes(5));C.Properties.VariableNames={'CPC'};
M=retime(metrics,'regular','mean','TimeStep',minutes(5));
W=retime(weather,'regular','nearest','TimeStep',minutes(5));
W=W(:,setdiff(W.Properties.VariableNames,{'Condition','Visibility'},'stable'));
if ~isempty(airQuality),A=retime(airQuality,'regular','nearest','TimeStep',minutes(5));else,A=timetable;end
T=synchronize(C,M,W,A,'union');d0=max(cpc.Time(1),smps.Time(1));d1=min(cpc.Time(end),smps.Time(end));T=T(T.Time>=d0&T.Time<=d1,:);

out=struct;out.generated=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z'));
out.site=struct('name',char(site.Name),'latitude',site.Latitude,'longitude',site.Longitude, ...
 'weatherName',char(site.WeatherStationName),'weatherLatitude',site.WeatherStationLatitude,'weatherLongitude',site.WeatherStationLongitude, ...
 'airName',char(site.AirQualityStationName),'airLatitude',site.AirQualityStationLatitude,'airLongitude',site.AirQualityStationLongitude, ...
 'air2Name',char(site.AirQualitySecondaryName),'air2Latitude',site.AirQualitySecondaryLatitude,'air2Longitude',site.AirQualitySecondaryLongitude);
out.time=cellstr(string(T.Time,'yyyy-MM-dd''T''HH:mm:ssXXX'));
names=T.Properties.VariableNames;out.series=struct;
for k=1:numel(names),out.series.(names{k})=finiteOrNull(T.(names{k}));end

H=retime(smps(:,2:end),'regular','mean','TimeStep',minutes(30));
out.heatmap=struct('time',{cellstr(string(H.Time,'yyyy-MM-dd''T''HH:mm:ssXXX'))},'sizes',sizes,'z',finiteOrNull(H{:,:}'));
out.labels=labelCatalog;
json=jsonencode(out);writeJson(file,json);
fprintf('Webdaten geschrieben: %s (%.1f MB)\n',file,numel(json)/1024/1024);
end

function writeJson(file,json)
fid=fopen(file,'w','n','UTF-8');cleanup=onCleanup(@()fclose(fid));fwrite(fid,json,'char');
end

function x=finiteOrNull(x)
% jsonencode bildet NaN in MATLAB als null ab; Inf wird vorsorglich entfernt.
x(~isfinite(x))=NaN;
end

function L=labelCatalog
L=struct('CPC','CPC Gesamt (#/cm³)','SMPSTotal','SMPS Gesamt (#/cm³)', ...
 'GeometricMeanDiameter','Geometrischer Mitteldurchmesser (nm)','GeometricStdDev','Geometrische Standardabweichung', ...
 'ModeDiameter','Modusdurchmesser (nm)','FractionBelow30nm','Anteil <30 nm','FractionBelow100nm','Anteil <100 nm', ...
 'FractionAbove100nm','Anteil ≥100 nm','Temperature','Temperatur (°C)','RelativeHumidity','Relative Feuchte (%)', ...
 'DewPoint','Taupunkt (°C)','PressureMSL','Luftdruck (hPa)','Precipitation','Regen (mm/h)', ...
 'Sunshine','Sonnenschein (min)','SolarRadiation','Solarstrahlung (W/m²)','CloudCover','Bewölkung (%)', ...
 'WindSpeed','Windgeschwindigkeit (m/s)','WindDirection','Windrichtung (°)','WindGustSpeed','Windböe (m/s)', ...
 'UVIndex','UV-Index','ARPA_NO2','NO₂ (µg/m³)','ARPA_NOX','NOₓ (µg/m³)','ARPA_NO','NO (µg/m³)', ...
 'ARPA_O3','O₃ (µg/m³)','ARPA_BENZENE','Benzol (µg/m³)','ARPA_PM10','PM₁₀ (µg/m³)','ARPA_PM2_5','PM₂.₅ (µg/m³)');
L.AQ_PM10='PM₁₀ Sternschanze (µg/m³)';L.AQ_PM2_5='PM₂.₅ Sternschanze (µg/m³)';L.AQ_SO2='SO₂ Sternschanze (µg/m³)';
L.AQ_O3='O₃ Sternschanze (µg/m³)';L.AQ_NO2='NO₂ Sternschanze (µg/m³)';L.AQ_NO='NO Sternschanze (µg/m³)';
L.AQ17SM_PM10='PM₁₀ Stresemannstraße (µg/m³)';L.AQ17SM_PM2_5='PM₂.₅ Stresemannstraße (µg/m³)';
L.AQ17SM_NO2='NO₂ Stresemannstraße (µg/m³)';L.AQ17SM_NO='NO Stresemannstraße (µg/m³)';
end
