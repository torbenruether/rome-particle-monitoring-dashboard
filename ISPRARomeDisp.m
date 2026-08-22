clear; close all; clc

%% Konfiguration: fuer weitere Standorte je einen struct-Eintrag anlegen
sites(1) = struct('Name',"ISPRA Rom",'WebID',"rome", ...
 'Latitude',41.798372,'Longitude',12.515188,'TimeZone',"Europe/Rome", ...
 'WeatherStationName',"Roma / Ciampino",'WeatherStationID',"16239", ...
 'WeatherStationLatitude',41.7833,'WeatherStationLongitude',12.5833, ...
 'AirQualityStationName',"ARPA Lazio Ciampino",'AirQualityStationID',"45", ...
 'AirQualityStationLatitude',41.797881,'AirQualityStationLongitude',12.607028, ...
 'AirQualitySecondaryName',"ARPA Lazio Cinecitta",'AirQualitySecondaryID',"8", ...
 'AirQualitySecondaryLatitude',41.857716,'AirQualitySecondaryLongitude',12.568652, ...
 'AirQualityProvider',"ARPA_Lazio",'CPCFolder',"CPCData",'CPCPattern',"*.csv",'SMPSFolder',"SMPSData",'SMPSPattern',"SMPS*.csv");
sites(2) = struct('Name',"Hamburg Sternschanze",'WebID',"hamburg", ...
 'Latitude',53.564493,'Longitude',9.968346,'TimeZone',"Europe/Berlin", ...
 'WeatherStationName',"Hamburg-Fuhlsbuettel",'WeatherStationID',"10147", ...
 'WeatherStationLatitude',53.633187,'WeatherStationLongitude',9.988085, ...
 'AirQualityStationName',"Hamburger Luftmessnetz Sternschanze",'AirQualityStationID',"13st", ...
 'AirQualityStationLatitude',53.564486,'AirQualityStationLongitude',9.968340, ...
 'AirQualitySecondaryName',"Hamburger Luftmessnetz Stresemannstrasse",'AirQualitySecondaryID',"17sm", ...
 'AirQualitySecondaryLatitude',53.560862,'AirQualitySecondaryLongitude',9.957387, ...
 'AirQualityProvider',"Hamburg_Luftmessnetz",'CPCFolder',"Hamburg",'CPCPattern',"CPC*.csv",'SMPSFolder',"Hamburg",'SMPSPattern',"SMPS*.csv");
cfg.DownloadWeather=true; cfg.ForceWeatherRefresh=true; cfg.EventWindow=hours(2); cfg.EventMADFactor=6;
cfg.DownloadAirQuality=true; cfg.ForceAirQualityRefresh=true;
cfg.MinimumEventLength=seconds(30); cfg.MinimumWindSpeed=0.5;
cfg.OutputFolder="results";
cfg.LaunchGUI=true;

% Optionale bekannte Quellen (WGS84). Beispiel:
% sources=table([53.57;53.55],[9.95;10.01],["A";"B"], ...
%  'VariableNames',{'Latitude','Longitude','Name'});
sources=table('Size',[0 3],'VariableTypes',{'double','double','string'}, ...
 'VariableNames',{'Latitude','Longitude','Name'});
if ~isfolder(cfg.OutputFolder), mkdir(cfg.OutputFolder); end

%% Analyse
results=cell(numel(sites),1);
for s=1:numel(sites)
 site=sites(s); fprintf('\n--- %s ---\n',site.Name);
 cpc=readCPC(site); [smps,sizes]=readSMPS(site);
 if isempty(cpc) && isempty(smps), warning('Keine Daten fuer %s.',site.Name); continue; end
 times=[cpc.Time;smps.Time]; d0=dateshift(min(times),'start','day'); d1=dateshift(max(times),'start','day');
 weather=loadWeather(site,d0,d1,cfg);
 airQuality=loadAirQuality(site,d0,d1,cfg);
 dayCPC=groupCPC(cpc,"day"); weekdayCPC=groupCPC(cpc,"weekday"); typeCPC=groupCPC(cpc,"daytype");
 events=detectEvents(cpc,weather,site,sources,cfg);
 tag=regexprep(site.Name,'[^A-Za-z0-9_-]','_');
 writeIfNotEmpty(dayCPC,fullfile(cfg.OutputFolder,tag+"_CPC_Tage.csv"));
 writeIfNotEmpty(weekdayCPC,fullfile(cfg.OutputFolder,tag+"_CPC_Wochentage.csv"));
 writeIfNotEmpty(typeCPC,fullfile(cfg.OutputFolder,tag+"_CPC_Werktag_Wochenende.csv"));
 writeIfNotEmpty(events,fullfile(cfg.OutputFolder,tag+"_Partikelereignisse.csv"));
 if ~isempty(weather), writeIfNotEmpty(timetable2table(weather,'ConvertRowTimes',true),fullfile(cfg.OutputFolder,tag+"_Wetter_Stuendlich.csv")); end
 if ~isempty(airQuality), writeIfNotEmpty(timetable2table(airQuality,'ConvertRowTimes',true),fullfile(cfg.OutputFolder,tag+"_Luftqualitaet.csv")); end
 if ~isempty(smps)
  writeIfNotEmpty(smpsDays(smps,sizes),fullfile(cfg.OutputFolder,tag+"_SMPS_Tage.csv"));
  smpsMetrics=computeSMPSMetrics(smps,sizes);
  writeIfNotEmpty(compareTotals(cpc,smpsMetrics,"period"),fullfile(cfg.OutputFolder,tag+"_Vergleich_Gesamtzeitraum.csv"));
  writeIfNotEmpty(compareTotals(cpc,smpsMetrics,"week"),fullfile(cfg.OutputFolder,tag+"_Vergleich_Wochen.csv"));
  writeIfNotEmpty(compareTotals(cpc,smpsMetrics,"daytype"),fullfile(cfg.OutputFolder,tag+"_Vergleich_Werktag_Wochenende.csv"));
 end
 correlations=correlationTables(cpc,smps,sizes,weather,airQuality);
 writeIfNotEmpty(correlations.CPC,fullfile(cfg.OutputFolder,tag+"_Korrelationen_CPC.csv"));
 writeIfNotEmpty(correlations.Metrics,fullfile(cfg.OutputFolder,tag+"_Korrelationen_SMPS_Kennwerte.csv"));
 writeIfNotEmpty(correlations.CPCvsSMPS,fullfile(cfg.OutputFolder,tag+"_Korrelation_CPC_SMPS_Gesamt.csv"));
 if isfolder('docs'),exportWebData(cpc,smps,sizes,weather,airQuality,site,fullfile('docs','data',site.WebID+"-monitoring.json"));end
 if cfg.LaunchGUI,ParticleAnalysisGUI(cpc,smps,sizes,weather,airQuality,site);end
 results{s}=struct('CPC',cpc,'SMPS',smps,'Weather',weather,'AirQuality',airQuality,'Events',events);
end

% Automatischer Standortvergleich, sobald mehrere Standorte konfiguriert sind
valid=~cellfun(@isempty,results);
if nnz(valid)>1
 figure('Name','Standortvergleich CPC'); hold on
 for s=find(valid)', d=groupCPC(results{s}.CPC,"day"); plot(d.Group,d.Mean,'-o','DisplayName',sites(s).Name); end
 ylabel('CPC-Mittelwert (#/cm^3)'); xlabel('Tag'); grid on; legend('Location','best')
end

%% Lokale Funktionen
function tt=readCPC(site)
 f=dir(fullfile(site.CPCFolder,site.CPCPattern)); p=cell(numel(f),1);
 for k=1:numel(f)
  file=fullfile(f(k).folder,f(k).name);
  try
   o=detectImportOptions(file,'NumHeaderLines',21,'VariableNamingRule','preserve'); o.SelectedVariableNames=o.VariableNames(1:3);o=setvartype(o,o.VariableNames{1},'string');
   T=readtable(file,o); t=parseDateTime(string(T{:,1}),site.TimeZone); x=double(T{:,3});
   ok=~isnat(t)&isfinite(x)&x>=0; p{k}=timetable(t(ok),x(ok),repmat(string(site.Name),nnz(ok),1),'VariableNames',{'Concentration','Site'});
  catch ME, warning('CPC-Datei %s uebersprungen: %s',file,ME.message); end
 end
 p=p(~cellfun(@isempty,p)); if isempty(p),tt=timetable;return;end
 tt=sortrows(vertcat(p{:})); [~,i]=unique(tt.Time,'stable'); tt=tt(i,:);
end

function [tt,sizes]=readSMPS(site)
 f=dir(fullfile(site.SMPSFolder,site.SMPSPattern)); p=cell(numel(f),1); sizes=[];
 for k=1:numel(f)
  file=fullfile(f(k).folder,f(k).name);
  try
   h=split(string(headerLine(file,53)),','); first=find(isfinite(str2double(h))&str2double(h)>0,1); raw=find(startsWith(h,"_"),1);
   sz=str2double(h(first:raw-1)); o=detectImportOptions(file,'NumHeaderLines',52,'VariableNamingRule','preserve');
   o=setvartype(o,o.VariableNames{2},'string'); T=readtable(file,o);
   t=datetime(string(T{:,2}),'InputFormat','dd/MM/yyyy HH:mm:ss','TimeZone',site.TimeZone); z=double(T{:,first:raw-1}); ok=~isnat(t)&any(isfinite(z),2);
   if isempty(sizes),sizes=sz(:)';elseif numel(sz)~=numel(sizes)||any(abs(sz(:)-sizes(:))>1e-6),error('Abweichende Partikelklassen.');end
   V=array2table(z(ok,:),'VariableNames',compose('Dp_%gnm',sizes)); V.Site=repmat(string(site.Name),nnz(ok),1); V=movevars(V,'Site','Before',1);
   p{k}=table2timetable(V,'RowTimes',t(ok));
  catch ME, warning('SMPS-Datei %s uebersprungen: %s',file,ME.message); end
 end
 p=p(~cellfun(@isempty,p)); if isempty(p),tt=timetable;return;end
 tt=sortrows(vertcat(p{:})); [~,i]=unique(tt.Time,'stable'); tt=tt(i,:);
end

function line=headerLine(file,n)
 fid=fopen(file,'r'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
 for i=1:n,line=fgetl(fid);end
end

function aq=loadAirQuality(site,d0,d1,cfg)
 if site.AirQualityProvider=="Hamburg_Luftmessnetz"
  aq=loadHamburgAirQuality(site,d0,d1,cfg);return
 end
 % Naechste offizielle Luftguetestelle: ARPA Lazio Ciampino (Code 45).
 folder=fullfile(cfg.OutputFolder,'air_quality_cache');if ~isfolder(folder),mkdir(folder);end
 stem=sprintf('arpa_%s_%s_%s',site.AirQualityStationID,datestr(d0,'yyyymmdd'),datestr(d1,'yyyymmdd'));
 cacheFile=fullfile(folder,[stem '.csv']);
 if isfile(cacheFile)&&~cfg.ForceAirQualityRefresh
  T=readtable(cacheFile);t=T.Time;if ~isdatetime(t),t=datetime(t);end;t.TimeZone=site.TimeZone;aq=table2timetable(T(:,2:end),'RowTimes',t);return
 end
 if ~cfg.DownloadAirQuality,aq=timetable;return;end
 pollutants={'NO2','NOX','NO','O3','CO','BENZENE','PM10','PM2.5','SO2'};parts=cell(numel(pollutants),1);
 try
  for p=1:numel(pollutants)
   if ismember(pollutants{p},{'O3','PM2.5'}),stationID=site.AirQualitySecondaryID;else,stationID=site.AirQualityStationID;end
   years=year(d0):year(d1);yparts=cell(numel(years),1);
   for yi=1:numel(years)
    y=years(yi);name=sprintf('RM_%s_%d.txt',pollutants{p},y);local=fullfile(folder,name);
    if y==year(datetime('today'))
     url=sprintf('https://www.arpalazio.net/main/aria/sci/annoincorso/chimici/RM/DatiOrari/%s',name);
    else
     url=sprintf('https://www.arpalazio.net/main/aria/sci/basedati/chimici/BDchimici/RM/DatiOrari/%s',name);
    end
    websave(local,url);fid=fopen(local,'r');cleanup=onCleanup(@()fclose(fid));header=str2double(split(strtrim(fgetl(fid))));
    stationColumn=find(header==str2double(stationID),1);ncol=numel(header);raw=textscan(fid,repmat('%f',1,ncol),'CollectOutput',true);M=raw{1};clear cleanup
    if isempty(stationColumn)||isempty(M),yparts{yi}=timetable;continue;end
    t=datetime(y,1,1,0,0,0,'TimeZone',site.TimeZone)+days(M(:,1)-1)+hours(M(:,2)-1);v=M(:,stationColumn);v(v<=-900)=NaN;
    yparts{yi}=timetable(t,v,'VariableNames',{['ARPA_' strrep(pollutants{p},'.','_')]});yparts{yi}.Properties.DimensionNames{1}='Time';
   end
   yparts=yparts(~cellfun(@isempty,yparts));if ~isempty(yparts),parts{p}=vertcat(yparts{:});end
  end
  parts=parts(~cellfun(@isempty,parts));if isempty(parts),aq=timetable;return;end
  aq=parts{1};for p=2:numel(parts),aq=synchronize(aq,parts{p},'union');end
  aq=aq(aq.Time>=d0&aq.Time<d1+days(1),:);aq.Properties.DimensionNames{1}='Time';
  keep=false(1,width(aq));for p=1:width(aq),keep(p)=any(isfinite(aq{:,p}));end;aq=aq(:,keep);
  out=timetable2table(aq,'ConvertRowTimes',true);out.Properties.VariableNames{1}='Time';writetable(out,cacheFile);
  dist=haversineKm(site.Latitude,site.Longitude,site.AirQualityStationLatitude,site.AirQualityStationLongitude);
  dist2=haversineKm(site.Latitude,site.Longitude,site.AirQualitySecondaryLatitude,site.AirQualitySecondaryLongitude);
  S=table([site.AirQualityStationName;site.AirQualitySecondaryName],[site.AirQualityStationID;site.AirQualitySecondaryID], ...
   [site.AirQualityStationLatitude;site.AirQualitySecondaryLatitude],[site.AirQualityStationLongitude;site.AirQualitySecondaryLongitude],[dist;dist2], ...
   ["NO, NO2, NOx, Benzol, PM10 (naechste verfuegbare Station)";"O3 und PM2.5 (naechste Station mit verfuegbaren Werten)"], ...
   'VariableNames',{'StationName','StationID','Latitude','Longitude','DistanceKm','MeasuredParameters'});writetable(S,fullfile(folder,[stem '_source.csv']));
  fprintf('Luftguetestationen: %s %.2f km; %s %.2f km\n',site.AirQualityStationName,dist,site.AirQualitySecondaryName,dist2);
 catch ME
  warning('ARPA-Luftqualitaetsabruf fehlgeschlagen: %s',ME.message)
  if isfile(cacheFile),T=readtable(cacheFile);t=T.Time;if ~isdatetime(t),t=datetime(t);end;t.TimeZone=site.TimeZone;aq=table2timetable(T(:,2:end),'RowTimes',t);else,aq=timetable;end
 end
end

function aq=loadHamburgAirQuality(site,d0,d1,cfg)
folder=fullfile(cfg.OutputFolder,'air_quality_cache');if ~isfolder(folder),mkdir(folder);end
stem=sprintf('hamburg_%s_%s_%s',site.AirQualityStationID,datestr(d0,'yyyymmdd'),datestr(d1,'yyyymmdd'));
cacheFile=fullfile(folder,[stem '.csv']);
if isfile(cacheFile)&&~cfg.ForceAirQualityRefresh
 T=readtable(cacheFile);t=T.Time;if ~isdatetime(t),t=datetime(t);end;t.TimeZone=site.TimeZone;aq=table2timetable(T(:,2:end),'RowTimes',t);return
end
if ~cfg.DownloadAirQuality,aq=timetable;return;end
try
 primary=hamburgStation(site.AirQualityStationID,"AQ_",site,d0,d1,folder);
 secondary=hamburgStation(site.AirQualitySecondaryID,"AQ17SM_",site,d0,d1,folder);
 aq=synchronize(primary,secondary,'union');aq=aq(aq.Time>=d0&aq.Time<d1+days(1),:);aq.Properties.DimensionNames{1}='Time';
 out=timetable2table(aq,'ConvertRowTimes',true);out.Properties.VariableNames{1}='Time';writetable(out,cacheFile);
 dist=haversineKm(site.Latitude,site.Longitude,site.AirQualityStationLatitude,site.AirQualityStationLongitude);
 dist2=haversineKm(site.Latitude,site.Longitude,site.AirQualitySecondaryLatitude,site.AirQualitySecondaryLongitude);
 S=table([site.AirQualityStationName;site.AirQualitySecondaryName],[site.AirQualityStationID;site.AirQualitySecondaryID], ...
  [site.AirQualityStationLatitude;site.AirQualitySecondaryLatitude],[site.AirQualityStationLongitude;site.AirQualitySecondaryLongitude],[dist;dist2], ...
  ["PM10, PM2.5, SO2, O3, NO2, NO (ko-lokalisierte Hintergrundstation)";"PM10, PM2.5, NO2, NO (nahe Verkehrsstation)"], ...
  'VariableNames',{'StationName','StationID','Latitude','Longitude','DistanceKm','MeasuredParameters'});writetable(S,fullfile(folder,[stem '_sources.csv']));
 fprintf('Luftguetestationen: %s %.3f km; %s %.2f km\n',site.AirQualityStationName,dist,site.AirQualitySecondaryName,dist2);
catch ME
 warning('Hamburger Luftqualitaetsabruf fehlgeschlagen: %s',ME.message)
 if isfile(cacheFile),T=readtable(cacheFile);t=T.Time;if ~isdatetime(t),t=datetime(t);end;t.TimeZone=site.TimeZone;aq=table2timetable(T(:,2:end),'RowTimes',t);else,aq=timetable;end
end
end

function tt=hamburgStation(stationID,prefix,site,d0,d1,folder)
url=sprintf(['https://hamburg.luftmessnetz.de/station/%s.csv?end%%5Bdate%%5D=%s&end%%5Bhour%%5D=23&group=pollution&period=1h' ...
 '&start%%5Bdate%%5D=%s&start%%5Bhour%%5D=00&timespan=custom'],stationID,datestr(d1,'dd.mm.yyyy'),datestr(d0,'dd.mm.yyyy'));
local=fullfile(folder,sprintf('%s_%s_%s.csv',stationID,datestr(d0,'yyyymmdd'),datestr(d1,'yyyymmdd')));websave(local,url);
fid=fopen(local,'r','n','UTF-8');cleanup=onCleanup(@()fclose(fid));fgetl(fid);components=split(string(fgetl(fid)),';');fgetl(fid);fgetl(fid);
nComponents=numel(components)-1;fmt=['%s' repmat('%f',1,nComponents)];R=textscan(fid,fmt,'Delimiter',';','TreatAsEmpty',{'','-'},'EmptyValue',NaN,'ReturnOnError',false);clear cleanup
n=min(cellfun(@numel,R));t=datetime(string(R{1}(1:n)),'InputFormat','dd.MM.yyyy HH:mm','TimeZone',site.TimeZone);X=nan(n,nComponents);for j=1:nComponents,X(:,j)=R{j+1}(1:n);end
componentNames=replace(components(2:end),["Feinstaub (PM10)","Feinstaub (PM2,5)","Schwefeldioxid","Ozon","Stickstoffdioxid","Stickstoffmonoxid"],["PM10","PM2_5","SO2","O3","NO2","NO"]);
names=prefix+componentNames;tt=array2timetable(X,'RowTimes',t,'VariableNames',cellstr(names));tt.Properties.DimensionNames{1}='Time';
keep=any(isfinite(X),1);tt=tt(:,keep);
end

function weather=loadWeather(site,d0,d1,cfg)
 folder=fullfile(cfg.OutputFolder,'weather_cache');if ~isfolder(folder),mkdir(folder);end
 stem=sprintf('weather_%.5f_%.5f_%s_%s',site.Latitude,site.Longitude,datestr(d0,'yyyymmdd'),datestr(d1,'yyyymmdd'));
 file=fullfile(folder,[stem '.csv']);metaFile=fullfile(folder,[stem '_sources.csv']);
 if isfile(file)&&~cfg.ForceWeatherRefresh
  T=readtable(file);t=T.Time;if ~isdatetime(t),t=datetime(t);end;t.TimeZone=site.TimeZone;
  weather=table2timetable(T(:,2:end),'RowTimes',t);return
 end
 if ~cfg.DownloadWeather,weather=timetable;return;end
 try
  % Naechste konfigurierte langjaehrige SYNOP/METAR-Station via Meteostat.
  parts=cell(numel(year(d0):year(d1)),1);years=year(d0):year(d1);
  for y=years
   gz=fullfile(folder,sprintf('%s_%d.csv.gz',site.WeatherStationID,y));rawFolder=fullfile(folder,sprintf('%s_%d',site.WeatherStationID,y));
   websave(gz,sprintf('https://data.meteostat.net/hourly/%d/%s.csv.gz',y,site.WeatherStationID));
   if ~isfolder(rawFolder),mkdir(rawFolder);end;names=gunzip(gz,rawFolder);parts{y-years(1)+1}=readtable(names{1});
  end
  M=vertcat(parts{:});t=datetime(M.year,M.month,M.day,M.hour,0,0,'TimeZone','UTC');t.TimeZone=site.TimeZone;
  ok=t>=d0&t<d1+days(1);t=t(ok);M=M(ok,:);dew=M.temp-(100-M.rhum)/5;
  weather=timetable(t,M.temp,M.rhum,dew,M.pres,M.prcp,M.tsun,nan(height(M),1),M.cldc,nan(height(M),1), ...
   M.wspd/3.6,M.wdir,M.wpgt/3.6,string(M.coco), ...
   'VariableNames',{'Temperature','RelativeHumidity','DewPoint','PressureMSL','Precipitation','Sunshine','SolarRadiation', ...
   'CloudCover','Visibility','WindSpeed','WindDirection','WindGustSpeed','Condition'});
  % Strahlung und UV am exakten Messpunkt aus dem historischen Modellraster.
  uq=sprintf(['https://historical-forecast-api.open-meteo.com/v1/forecast?latitude=%.6f&longitude=%.6f&start_date=%s&end_date=%s' ...
   '&hourly=shortwave_radiation,uv_index&timezone=%s'],site.Latitude,site.Longitude,datestr(d0,'yyyy-mm-dd'),datestr(d1,'yyyy-mm-dd'),char(site.TimeZone));
  U=webread(uq);ut=datetime(string(U.hourly.time),'InputFormat','yyyy-MM-dd''T''HH:mm','TimeZone',site.TimeZone);
  ok=~isnat(ut);extra=timetable(ut(ok),U.hourly.shortwave_radiation(ok),U.hourly.uv_index(ok),'VariableNames',{'SolarGrid','UVIndex'});
  weather=synchronize(weather,extra,'union','nearest');weather.SolarRadiation=weather.SolarGrid;weather.SolarGrid=[];
  weather.Properties.DimensionNames{1}='Time';
  out=timetable2table(weather,'ConvertRowTimes',true);out.Properties.VariableNames{1}='Time';writetable(out,file);
  dist=haversineKm(site.Latitude,site.Longitude,site.WeatherStationLatitude,site.WeatherStationLongitude);
  S=table(site.WeatherStationName,site.WeatherStationID,site.WeatherStationLatitude,site.WeatherStationLongitude,dist, ...
   "Meteostat METAR/SYNOP; Solar/UV: Open-Meteo Raster",'VariableNames',{'StationName','StationID','Latitude','Longitude','DistanceKm','Source'});
  writetable(S,metaFile);fprintf('Wetterstation: %s (%s), Entfernung %.2f km\n',site.WeatherStationName,site.WeatherStationID,dist);
 catch ME
  warning('Aktueller Wetterabruf fehlgeschlagen: %s',ME.message)
  if isfile(file)
   T=readtable(file);t=T.Time;if ~isdatetime(t),t=datetime(t);end;t.TimeZone=site.TimeZone;
   weather=table2timetable(T(:,2:end),'RowTimes',t);warning('Vorhandener Wetter-Cache wird verwendet.');
  else,weather=timetable;end
 end
end

function t=parseDateTime(s,tz)
formats=["yyyy-MM-dd HH:mm:ss","dd/MM/yyyy HH:mm:ss","dd.MM.yyyy HH:mm:ss"];
t=NaT(size(s),'TimeZone',tz);
for k=1:numel(formats)
 missing=isnat(t);if ~any(missing),break;end
 try,p=datetime(s(missing),'InputFormat',formats(k),'TimeZone',tz);t(missing)=p;catch,end
end
end

function d=haversineKm(a,b,c,e)
 R=6371;da=deg2rad(c-a);db=deg2rad(e-b);q=sin(da/2)^2+cos(deg2rad(a))*cos(deg2rad(c))*sin(db/2)^2;d=2*R*atan2(sqrt(q),sqrt(1-q));
end

function out=groupCPC(cpc,mode)
 if isempty(cpc),out=table;return;end;t=cpc.Time;x=cpc.Concentration;
 switch mode
  case "day", label=dateshift(t,'start','day');
  case "weekday"
   n=weekday(t); names=["Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"];
   label=categorical(names(n)',names([2:7 1]),'Ordinal',true);
  case "daytype",label=repmat("Werktag",height(cpc),1);label(isweekend(t))="Wochenende";label=categorical(label);
 end
 [G,u]=findgroups(label);out=table(u,splitapply(@(v)mean(v,'omitnan'),x,G),splitapply(@(v)median(v,'omitnan'),x,G), ...
  splitapply(@(v)std(v,'omitnan'),x,G),splitapply(@numel,x,G),'VariableNames',{'Group','Mean','Median','Std','N'});
end

function out=smpsDays(smps,sizes)
 [G,u]=findgroups(dateshift(smps.Time,'start','day'));X=smps{:,2:end};M=splitapply(@(v)mean(v,1,'omitnan'),X,G);
 out=array2table(M,'VariableNames',compose('Dp_%gnm',sizes));out.Day=u;out=movevars(out,'Day','Before',1);
end

function out=compareTotals(cpc,metrics,mode)
 if isempty(cpc)||isempty(metrics),out=table;return;end
 C=retime(cpc(:,{'Concentration'}),'hourly','mean');M=retime(metrics(:,{'SMPSTotal'}),'hourly','mean');A=synchronize(C,M,'intersection');
 switch mode
  case "period",label=repmat("Gesamtzeitraum",height(A),1);
  case "week",n=weekday(A.Time);label=dateshift(A.Time-days(mod(n-2,7)),'start','day');
  case "daytype",label=repmat("Werktag",height(A),1);label(isweekend(A.Time))="Wochenende";
 end
 [G,u]=findgroups(label);out=table(u,splitapply(@(x)mean(x,'omitnan'),A.Concentration,G),splitapply(@(x)median(x,'omitnan'),A.Concentration,G), ...
  splitapply(@(x)mean(x,'omitnan'),A.SMPSTotal,G),splitapply(@(x)median(x,'omitnan'),A.SMPSTotal,G),splitapply(@numel,A.Concentration,G), ...
  'VariableNames',{'Group','CPCMean','CPCMedian','SMPSMean','SMPSMedian','N'});
end

function e=detectEvents(cpc,wind,site,sources,cfg)
 if isempty(cpc),e=table;return;end;x=cpc.Concentration;dt=median(seconds(diff(cpc.Time)));w=max(3,round(seconds(cfg.EventWindow)/dt));
 bg=movmedian(x,w,'omitnan');thr=bg+cfg.EventMADFactor*movmedian(abs(x-bg),w,'omitnan');flag=x>thr;
 edge=diff([false;flag;false]);a=find(edge==1);b=find(edge==-1)-1;keep=cpc.Time(b)-cpc.Time(a)>=cfg.MinimumEventLength;a=a(keep);b=b(keep);n=numel(a);
 e=table('Size',[n 10],'VariableTypes',{'datetime','datetime','double','double','double','double','double','string','double','string'}, ...
  'VariableNames',{'Start','End','Peak','Mean','WindSpeed','WindDirection','UpwindBearing','CandidateSource','DirectionDifference','Assessment'});
 e.Start=NaT(n,1,'TimeZone',cpc.Time.TimeZone);e.End=NaT(n,1,'TimeZone',cpc.Time.TimeZone);
 for i=1:n
  ii=a(i):b(i);[e.Peak(i),p]=max(x(ii));e.Mean(i)=mean(x(ii),'omitnan');e.Start(i)=cpc.Time(a(i));e.End(i)=cpc.Time(b(i));
  e.CandidateSource(i)="";e.DirectionDifference(i)=NaN;e.Assessment(i)="keine Winddaten";
  if ~isempty(wind)
   [~,j]=min(abs(wind.Time-cpc.Time(ii(p))));e.WindSpeed(i)=wind.WindSpeed(j);e.WindDirection(i)=wind.WindDirection(j);e.UpwindBearing(i)=wind.WindDirection(j);
   if e.WindSpeed(i)<cfg.MinimumWindSpeed,e.Assessment(i)="Wind zu schwach";
   elseif isempty(sources),e.Assessment(i)="nur Richtungsindiz";
   else
    br=arrayfun(@(la,lo)bearing(site.Latitude,site.Longitude,la,lo),sources.Latitude,sources.Longitude);delta=abs(mod(br-e.UpwindBearing(i)+180,360)-180);[d,k]=min(delta);
    e.CandidateSource(i)=sources.Name(k);e.DirectionDifference(i)=d;if d<=22.5,e.Assessment(i)="Kandidat im Windsektor";else,e.Assessment(i)="kein Kandidat im Windsektor";end
   end
  end
 end
end

function b=bearing(la1,lo1,la2,lo2)
 dl=deg2rad(lo2-lo1);y=sin(dl).*cos(deg2rad(la2));x=cos(deg2rad(la1)).*sin(deg2rad(la2))-sin(deg2rad(la1)).*cos(deg2rad(la2)).*cos(dl);b=mod(rad2deg(atan2(y,x)),360);
end

function C=correlationTables(cpc,smps,sizes,weather,airQuality)
 C=struct('CPC',table,'Metrics',table,'CPCvsSMPS',table);if isempty(weather),return;end
 W=weatherPredictors(weather);names=W.Properties.VariableNames;
 if ~isempty(airQuality),W=synchronize(W,airQuality,'union');names=W.Properties.VariableNames;end
 if ~isempty(cpc)
  H=retime(cpc(:,{'Concentration'}),'hourly','mean');A=synchronize(H,W,'intersection');
  C.CPC=corrRows(A.Concentration,A,names,NaN);
 end
 if ~isempty(smps)
  metrics=computeSMPSMetrics(smps,sizes);MH=retime(metrics,'hourly','mean');B=synchronize(MH,W,'intersection');mnames=metrics.Properties.VariableNames;mr=cell(numel(mnames),1);
  for k=1:numel(mnames),mr{k}=corrMetricRows(B.(mnames{k}),B,names,mnames{k});end;C.Metrics=vertcat(mr{:});
  if ~isempty(cpc)
   CH=retime(cpc(:,{'Concentration'}),'hourly','mean');P=synchronize(CH,MH(:,{'SMPSTotal'}),'intersection');ok=isfinite(P.Concentration)&isfinite(P.SMPSTotal);
   [r,p]=corr(P.Concentration(ok),P.SMPSTotal(ok),'Type','Spearman');C.CPCvsSMPS=table(r,p,nnz(ok),'VariableNames',{'SpearmanRho','PValue','N'});
  end
 end
end

function T=corrMetricRows(y,A,names,metric)
 T=corrRows(y,A,names,NaN);T.Metric=repmat(string(metric),height(T),1);T=movevars(T,'Metric','Before',1);T.ParticleSizeNm=[];
end

function W=weatherPredictors(weather)
 keep={'Temperature','RelativeHumidity','DewPoint','PressureMSL','Precipitation','Sunshine','SolarRadiation','CloudCover','WindSpeed','WindGustSpeed','UVIndex'};
 keep=keep(ismember(keep,weather.Properties.VariableNames));W=weather(:,keep);
 if ismember('WindDirection',weather.Properties.VariableNames)
  W.WindFromEast=sin(deg2rad(weather.WindDirection));W.WindFromNorth=cos(deg2rad(weather.WindDirection));
 end
end

function T=corrRows(y,A,names,sizeNm)
 n=numel(names);rho=nan(n,1);p=nan(n,1);N=zeros(n,1);
 for j=1:n,x=A.(names{j});ok=isfinite(x)&isfinite(y);N(j)=nnz(ok);if N(j)>=4,[rho(j),p(j)]=corr(x(ok),y(ok),'Type','Spearman');end,end
 q=bhAdjust(p);T=table(repmat(sizeNm,n,1),string(names(:)),rho,p,q,N,'VariableNames',{'ParticleSizeNm','WeatherParameter','SpearmanRho','PValue','FDR_QValue','N'});
end

function q=bhAdjust(p)
 q=nan(size(p));ok=isfinite(p);[v,ord]=sort(p(ok));m=numel(v);adj=min(1,v.*m./(1:m)');adj=flipud(cummin(flipud(adj)));idx=find(ok);q(idx(ord))=adj;
end

function makeSourceMap(site,e)
 figure('Name',site.Name+" - Wind- und Quellenkarte");gx=geoaxes;hold(gx,'on');
 try,geobasemap(gx,'streets');catch,geobasemap(gx,'none');end
 geoscatter(gx,site.Latitude,site.Longitude,90,'r','filled','DisplayName','Partikelmessung');
 geoscatter(gx,site.WeatherStationLatitude,site.WeatherStationLongitude,70,'b','^','filled','DisplayName',site.WeatherStationName);
 if ~isempty(e)
  sector=mod(round(e.UpwindBearing/22.5)*22.5,360);u=unique(sector(isfinite(sector)));
  peakMax=max(e.Peak,[],'omitnan');
  for k=1:numel(u)
   ii=sector==u(k);strength=mean(e.Peak(ii),'omitnan')/peakMax;[la,lo]=destination(site.Latitude,site.Longitude,u(k),2+8*strength);
   geoplot(gx,[site.Latitude la],[site.Longitude lo],'-','LineWidth',1+5*strength,'DisplayName',sprintf('Wind aus %.0f Grad',u(k)));
  end
 end
 geolimits(gx,[site.Latitude-.12 site.Latitude+.12],[site.Longitude-.15 site.Longitude+.15]);legend(gx,'Location','best');title(gx,'Ereignisstaerke nach Herkunftsrichtung');
end

function [la2,lo2]=destination(la,lo,bearingDeg,distanceKm)
 R=6371;d=distanceKm/R;b=deg2rad(bearingDeg);p=deg2rad(la);l=deg2rad(lo);
 la2=rad2deg(asin(sin(p)*cos(d)+cos(p)*sin(d)*cos(b)));lo2=rad2deg(l+atan2(sin(b)*sin(d)*cos(p),cos(d)-sin(p)*sin(deg2rad(la2))));
end

function makePlots(site,cpc,smps,sizes,weather,wd,dt,e)
 if ~isempty(cpc)
  figure('Name',site.Name+" - Partikel und Wetter");tiledlayout(4,1);nexttile;plot(cpc.Time,cpc.Concentration,'k');ylabel('#/cm^3');title(site.Name);grid on;hold on
  if ~isempty(e),scatter(e.Start,e.Peak,28,'r','filled');end;xtickformat('dd.MM HH:mm')
  nexttile
  if isempty(weather),text(.1,.5,'Keine Wetterdaten');axis off
  else
   yyaxis left;plot(weather.Time,weather.WindSpeed);ylabel('Wind m/s');yyaxis right;plot(weather.Time,weather.WindDirection,'.-');ylabel('Richtung (aus)');ylim([0 360]);xtickformat('dd.MM HH:mm')
   nexttile;yyaxis left;plot(weather.Time,weather.Temperature);ylabel('Temperatur C');yyaxis right;plot(weather.Time,weather.PressureMSL);ylabel('Druck hPa');grid on;xtickformat('dd.MM HH:mm')
   nexttile;yyaxis left;stairs(weather.Time,weather.Precipitation);ylabel('Regen mm');yyaxis right;plot(weather.Time,weather.SolarRadiation);hold on;plot(weather.Time,weather.UVIndex);ylabel('W/m2 bzw. UV');legend('Solar','UV');grid on;xtickformat('dd.MM HH:mm')
  end
  figure('Name',site.Name+" - Gruppen");tiledlayout(1,2);nexttile;bar(categorical(string(wd.Group)),wd.Mean);title('Wochentage');ylabel('#/cm^3');nexttile;bar(categorical(string(dt.Group)),dt.Mean);title('Werktag / Wochenende');
 end
 if ~isempty(smps)
  figure('Name',site.Name+" - SMPS");imagesc(datenum(smps.Time),sizes,log10(max(smps{:,2:end}',1)));axis xy
  ax=gca;set(ax,'YScale','log');dynamicDatenumTicks(ax);ylabel('Partikelgroesse (nm)');xlabel('Zeit');cb=colorbar;cb.Label.String='log10(dN/dlogDp)';
  z=zoom(gcf);z.ActionPostCallback=@(~,~)dynamicDatenumTicks(ax);p=pan(gcf);p.ActionPostCallback=@(~,~)dynamicDatenumTicks(ax);
 end
end

function dynamicDatenumTicks(ax)
 span=diff(xlim(ax));if span<=1/12,fmt='HH:MM';elseif span<=2,fmt='dd.mm HH:MM';elseif span<=60,fmt='dd.mm';else,fmt='mmm yyyy';end
 datetick(ax,'x',fmt,'keeplimits');
end

function writeIfNotEmpty(T,file)
 if ~isempty(T),writetable(T,file);end
end
