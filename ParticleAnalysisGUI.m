function ParticleAnalysisGUI(cpc,smps,sizes,weather,airQuality,site)
% Uebersichtliche interaktive Partikel-, Wetter- und Kartenanalyse.
if isempty(weather),warning('GUI nicht gestartet: keine Wetterdaten.');return;end
metrics=computeSMPSMetrics(smps,sizes);W=guiWeather(weather);if ~isempty(airQuality),W=synchronize(W,airQuality,'union');end;predictors=W.Properties.VariableNames;
[choices,responses]=responseCatalog(cpc,smps,sizes,metrics);
mapStart=max([weather.Time(1),cpc.Time(1),metrics.Time(1)]);mapEnd=min([weather.Time(end),cpc.Time(end),metrics.Time(end)]);
animationRunning=false;

f=uifigure('Name','Partikel-Wetter-Labor: '+site.Name,'Position',[40 40 1550 900]);
root=uigridlayout(f,[1 1]);root.Padding=[8 8 8 8];

%% Registerkarten
tabs=uitabgroup(root);overviewTab=uitab(tabs,'Title','Übersicht & Vergleiche');dataTab=uitab(tabs,'Title','Datenplot');corrTab=uitab(tabs,'Title','Korrelationen');mapTab=uitab(tabs,'Title','Animation & Karte');
corrRoot=uigridlayout(corrTab,[1 2]);corrRoot.ColumnWidth={310,'1x'};

%% Bedienfeld
panel=uipanel(corrRoot,'Title','Auswahl und Analyse');panel.Layout.Column=1;
pg=uigridlayout(panel,[15 1]);pg.RowHeight={30,30,30,125,30,30,62,30,30,30,30,36,55,75,'1x'};
infoHeading(pg,'Partikeldaten','Waehlt CPC-Gesamtzahl, integrierte SMPS-Gesamtzahl oder einen physikalischen Kennwert der gesamten Groessenverteilung. Einzelne SMPS-Kanaele werden nicht verglichen.');
particle=uidropdown(pg,'Items',cellstr(choices),'Value',char(choices(1)));
infoHeading(pg,'Umweltparameter','Wetter und ARPA-Luftschadstoffe sind mehrfach waehlbar. Windrichtung wird zirkulaer als Nord- und Ostkomponente behandelt.');
vars=uilistbox(pg,'Items',predictors,'Multiselect','on','Value',predictors(1:min(3,end)));
infoHeading(pg,'Korrelationsart','Spearman bewertet monotone Zusammenhaenge robust; Pearson bewertet lineare Zusammenhaenge.');
method=uidropdown(pg,'Items',{'Spearman','Pearson'},'Value','Spearman');
corrHelp=uilabel(pg,'Text','Spearman vergleicht Rangfolgen und erkennt monotone Zusammenhänge. Pearson misst einen geradlinigen Zusammenhang und reagiert stärker auf Ausreißer.','WordWrap','on','Tooltip','r liegt zwischen -1 und +1. Das Vorzeichen zeigt die Richtung, der Betrag die Stärke des Zusammenhangs.'); %#ok<NASGU>
infoHeading(pg,'Zeitliche Aufloesung','Beide Datenreihen werden vor dem Vergleich auf dasselbe Zeitraster aggregiert.');
aggregation=uidropdown(pg,'Items',{'5 Minuten','30 Minuten','1 Stunde','12 Stunden','24 Stunden'},'Value','1 Stunde');
infoHeading(pg,'Wetter-Zeitversatz (Stunden)','Positive Werte verschieben das Wetter nach vorne: Ein Wetterzustand wird mit spaeteren Partikeldaten verglichen.');
lag=uispinner(pg,'Limits',[-48 48],'Step',1,'Value',0);
runButton=feval('uibutton',pg,'Text','Alle Ansichten aktualisieren','FontWeight','bold','ButtonPushedFcn',@refreshAll); %#ok<NASGU>
modelInfo=uilabel(pg,'Text','R² beschreibt den gemeinsam erklaerten Varianzanteil. Es ist kein Kausalitaetsnachweis.','WordWrap','on');
uilabel(pg,'Text','ⓘ Diese Auswahl steuert ausschließlich die Korrelationsanalyse in diesem Tab.','Tooltip','Übersicht und Karte besitzen feste, unmittelbar vergleichbare Darstellungen.','WordWrap','on');

og=uigridlayout(overviewTab,[3 2]);og.RowHeight={38,'1x','1x'};
note=uilabel(og,'Text','ⓘ Zeitachsen passen ihre Datumsbeschriftung beim Zoomen automatisch an.','Tooltip','Mit Lupe oder Mausrad zoomen; bei kuerzeren Zeitraeumen erscheinen Uhrzeiten und mehr Achsenwerte.');note.Layout.Column=[1 2];
axOverview=uiaxes(og);axOverview.Layout.Row=2;axOverview.Layout.Column=1;grid(axOverview,'on');title(axOverview,'CPC und SMPS-Gesamtkonzentration');
periodTable=uitable(og);periodTable.Layout.Row=2;periodTable.Layout.Column=2;
axWeekly=uiaxes(og);axWeekly.Layout.Row=3;axWeekly.Layout.Column=1;grid(axWeekly,'on');title(axWeekly,'Wöchentliche Mittelwerte');
axWorkday=uiaxes(og);axWorkday.Layout.Row=3;axWorkday.Layout.Column=2;grid(axWorkday,'on');title(axWorkday,'Werktag und Wochenende');

%% Frei kombinierbarer Dashboard-Datenplot
dg=uigridlayout(dataTab,[2 1]);dg.RowHeight={125,'1x'};
dataControls=uigridlayout(dg,[2 5]);dataControls.RowHeight={32,72};dataControls.ColumnWidth={130,280,130,180,180};
uilabel(dataControls,'Text','Datenreihen','FontWeight','bold','Tooltip','Mehrere Reihen koennen gemeinsam dargestellt werden.');
dashboardNames=["CPC Gesamt","SMPS Gesamt","SMPS Größenverteilung (Heatmap)",string(W.Properties.VariableNames)];
dashboardVars=uilistbox(dataControls,'Items',cellstr(dashboardNames),'Multiselect','on','Value',{'CPC Gesamt','SMPS Gesamt'});dashboardVars.Layout.Row=[1 2];dashboardVars.Layout.Column=2;
uilabel(dataControls,'Text','Mittelung','FontWeight','bold','Tooltip','Legt Raster und Mittelungsfenster des gemeinsamen Plots fest.');
dashboardAggregation=uidropdown(dataControls,'Items',{'5 Minuten','30 Minuten','1 Stunde','12 Stunden','24 Stunden'},'Value','1 Stunde');dashboardAggregation.Layout.Row=2;dashboardAggregation.Layout.Column=3;
dashboardMode=uidropdown(dataControls,'Items',{'Standardisiert gemeinsam','Eigene Y-Achsen'},'Value','Standardisiert gemeinsam','Tooltip','Standardisiert: alle Linien in einer Achse. Eigene Y-Achsen: eine synchronisierte Achse je Datenreihe.');dashboardMode.Layout.Row=2;dashboardMode.Layout.Column=4;
dashboardButton=feval('uibutton',dataControls,'Text','Plot aktualisieren','ButtonPushedFcn',@updateDashboard);dashboardButton.Layout.Row=2;dashboardButton.Layout.Column=5;
dashboardInfo=uilabel(dataControls,'Text','ⓘ Standardisiert lassen sich Partikel, Wind, Temperatur und Regen trotz verschiedener Einheiten in einem Plot vergleichen.','WordWrap','on');dashboardInfo.Layout.Row=1;dashboardInfo.Layout.Column=[3 5];
dashboardPanel=uipanel(dg,'BorderType','none');dashboardPanel.Layout.Row=2;dashboardGrid=uigridlayout(dashboardPanel,[1 1]);dashboardGrid.Padding=[5 5 5 5];

cg=uigridlayout(corrRoot,[2 3]);cg.Layout.Column=2;cg.RowHeight={205,'1x'};
summary=uitable(cg,'ColumnName',{'Parameter','r','p','N'});summary.Layout.Row=1;summary.Layout.Column=[1 3];
axTime=uiaxes(cg);axTime.Layout.Row=2;axTime.Layout.Column=1;grid(axTime,'on');title(axTime,'Messung und Mehrvariablen-Modell');
axScatter=uiaxes(cg);axScatter.Layout.Row=2;axScatter.Layout.Column=2;grid(axScatter,'on');title(axScatter,'Einzelkorrelation');
axBars=uiaxes(cg);axBars.Layout.Row=2;axBars.Layout.Column=3;grid(axBars,'on');title(axBars,'Alle gewaehlten Korrelationen');

mg=uigridlayout(mapTab,[2 2]);mg.RowHeight={'1x',230};mg.ColumnWidth={'1.1x','1x'};
mapPanel=uipanel(mg,'BorderType','none');mapPanel.Layout.Row=1;mapPanel.Layout.Column=1;mapAx=geoaxes(mapPanel,'Units','normalized','Position',[.01 .01 .98 .98]);
windInset=polaraxes(mapPanel,'Units','normalized','Position',[.60 .55 .36 .38],'Color',[1 1 1]);windInset.ThetaZeroLocation='top';windInset.ThetaDir='clockwise';
mapTrend=uiaxes(mg);mapTrend.Layout.Row=1;mapTrend.Layout.Column=2;grid(mapTrend,'on');title(mapTrend,'CPC und SMPS – Linie zeigt Kartenzeit');
mapControls=uigridlayout(mg,[6 4]);mapControls.Layout.Row=2;mapControls.Layout.Column=[1 2];mapControls.ColumnWidth={125,'1x',170,150};mapControls.RowHeight={25,38,34,34,34,28};
uilabel(mapControls,'Text','Zeitpunkt','Tooltip','Waehlt den Wetterzeitpunkt. CPC und SMPS werden jeweils auf die zeitlich naechste Messung gesetzt.');
tickValues=linspace(datenum(mapStart),datenum(mapEnd),5);
timeSlider=uislider(mapControls,'Limits',[datenum(mapStart) datenum(mapEnd)],'Value',datenum(mapEnd),'MajorTicks',tickValues,'MajorTickLabels',cellstr(string(datetime(tickValues,'ConvertFrom','datenum'),'dd.MM.yyyy')),'ValueChangedFcn',@updateMap);timeSlider.Layout.Column=[2 3];
latestButton=feval('uibutton',mapControls,'Text','Letzte Messung','ButtonPushedFcn',@latestMap);latestButton.Layout.Column=4;
mapTime=uilabel(mapControls,'Text','','FontSize',15,'FontWeight','bold','HorizontalAlignment','center');mapTime.Layout.Row=2;mapTime.Layout.Column=[1 4];
basemapDrop=uidropdown(mapControls,'Items',{'Straßenkarte','Satellit'},'Value','Straßenkarte','Tooltip','MATLAB-Straßenkarte oder Satellitenbild. Google Maps selbst erfordert einen separaten Google-API-Schlüssel und Lizenzbedingungen.','ValueChangedFcn',@updateMap);basemapDrop.Layout.Row=2;basemapDrop.Layout.Column=4;mapTime.Layout.Column=[1 3];
cpcCard=uilabel(mapControls,'Text','','FontSize',14,'FontWeight','bold','BackgroundColor',[1 .86 .86],'HorizontalAlignment','center','Tooltip','CPC-Gesamtzahl im gewählten Mittelungsfenster.');cpcCard.Layout.Row=3;cpcCard.Layout.Column=[1 2];
smpsCard=uilabel(mapControls,'Text','','FontSize',14,'FontWeight','bold','BackgroundColor',[.82 .94 1],'HorizontalAlignment','center','Tooltip','Integrierte SMPS-Gesamtzahl im gewählten Mittelungsfenster.');smpsCard.Layout.Row=3;smpsCard.Layout.Column=[3 4];
aggregationLabel=uilabel(mapControls,'Text','Animationsmittel','FontWeight','bold','Tooltip','Bestimmt sowohl Schrittweite als auch Mittelungsfenster jedes Animationsbildes.');aggregationLabel.Layout.Row=4;
mapAggregation=uidropdown(mapControls,'Items',{'5 Minuten','30 Minuten','1 Stunde','12 Stunden','24 Stunden'},'Value','1 Stunde','ValueChangedFcn',@updateMap);mapAggregation.Layout.Row=4;mapAggregation.Layout.Column=2;
animationButton=feval('uibutton',mapControls,'Text','▶ Start','FontWeight','bold','ButtonPushedFcn',@toggleAnimation);animationButton.Layout.Row=4;animationButton.Layout.Column=3;
rainCheck=uicheckbox(mapControls,'Text','Regen überlagern','Value',true,'Tooltip','Blauer transparenter Kreis an der Wetterstation; Größe entspricht dem Niederschlag im Mittelungsfenster.','ValueChangedFcn',@updateMap);rainCheck.Layout.Row=4;rainCheck.Layout.Column=4;
windCard=uilabel(mapControls,'Text','','FontSize',13,'FontWeight','bold','BackgroundColor',[.92 .85 1],'HorizontalAlignment','center','Tooltip','Windrichtung bezeichnet die Herkunftsrichtung.');windCard.Layout.Row=5;windCard.Layout.Column=[1 4];
mapValues=uilabel(mapControls,'Text','Windrose und aktuelle ARPA-Luftqualität. PM₁₀/PM₂.₅ sind Tagesmittel; Gase liegen stündlich vor.','WordWrap','on','HorizontalAlignment','center','Tooltip','Wind unter 0,5 m/s wird ausgeschlossen.');mapValues.Layout.Row=6;mapValues.Layout.Column=[1 4];

particle.ValueChangedFcn=@refreshAll;vars.ValueChangedFcn=@refreshAll;method.ValueChangedFcn=@refreshAll;aggregation.ValueChangedFcn=@refreshAll;lag.ValueChangedFcn=@refreshAll;
dashboardVars.ValueChangedFcn=@updateDashboard;dashboardAggregation.ValueChangedFcn=@updateDashboard;dashboardMode.ValueChangedFcn=@updateDashboard;
drawOverview();updateDashboard();updateMap();refreshAll();

 function refreshAll(~,~)
  updateCorrelation();
 end

 function drawOverview()
  cla(axOverview);hold(axOverview,'on');
  if ~isempty(cpc)&&~isempty(metrics)
   C=retime(cpc(:,{'Concentration'}),'hourly','mean');M=retime(metrics(:,{'SMPSTotal'}),'hourly','mean');A=synchronize(C,M,'intersection');ok=isfinite(A.Concentration)&isfinite(A.SMPSTotal);
   plot(axOverview,A.Time,A.Concentration,'r','DisplayName','CPC');plot(axOverview,A.Time,A.SMPSTotal,'b','DisplayName','SMPS');legend(axOverview,'Location','best');ylabel(axOverview,'#/cm³');xtickformat(axOverview,'dd.MM HH:mm');
   [r,p]=corr(A.Concentration(ok),A.SMPSTotal(ok),'Type','Spearman');note.Text=sprintf('ⓘ Gesamtzeitraum: CPC–SMPS Spearman r=%.3f, p=%.3g, n=%d. Wochen beginnen montags.',r,p,nnz(ok));
   signal=["CPC";"SMPS integriert"];meanV=[mean(A.Concentration(ok));mean(A.SMPSTotal(ok))];medianV=[median(A.Concentration(ok));median(A.SMPSTotal(ok))];stdV=[std(A.Concentration(ok));std(A.SMPSTotal(ok))];N=repmat(nnz(ok),2,1);
   periodTable.Data=table(signal,meanV,medianV,stdV,N,'VariableNames',{'Signal','Mittelwert','Median','Standardabweichung','N'});
   weekdayNumber=weekday(A.Time);week=dateshift(A.Time-days(mod(weekdayNumber-2,7)),'start','day');[G,u]=findgroups(week);cw=splitapply(@(x)mean(x,'omitnan'),A.Concentration,G);mw=splitapply(@(x)mean(x,'omitnan'),A.SMPSTotal,G);
   cla(axWeekly);plot(axWeekly,u,cw,'-or','DisplayName','CPC');hold(axWeekly,'on');plot(axWeekly,u,mw,'-ob','DisplayName','SMPS');legend(axWeekly,'Location','best');ylabel(axWeekly,'Mittel #/cm³');xtickformat(axWeekly,'dd.MM');
   weekend=isweekend(A.Time);cm=[mean(A.Concentration(~weekend),'omitnan');mean(A.Concentration(weekend),'omitnan')];mm=[mean(A.SMPSTotal(~weekend),'omitnan');mean(A.SMPSTotal(weekend),'omitnan')];
   cla(axWorkday);bar(axWorkday,categorical(["Werktag","Wochenende"]),[cm mm]);legend(axWorkday,{'CPC','SMPS'},'Location','best');ylabel(axWorkday,'Mittel #/cm³');
  end
 end

 function updateDashboard(~,~)
  selected=string(dashboardVars.Value);isHeat=selected=="SMPS Größenverteilung (Heatmap)";lineNames=selected(~isHeat);delete(dashboardGrid.Children);
  ownAxes=strcmp(dashboardMode.Value,'Eigene Y-Achsen');rows=max(1,nnz(isHeat)+(ownAxes*numel(lineNames))+(~ownAxes&&~isempty(lineNames)));dashboardGrid.RowHeight=repmat({'1x'},1,rows);dashboardGrid.ColumnWidth={'1x'};row=0;
  if ~isempty(lineNames)&&~ownAxes
   row=row+1;ax=uiaxes(dashboardGrid);ax.Layout.Row=row;hold(ax,'on');grid(ax,'on');
   for k=1:numel(lineNames),[T,name]=dashboardSeries(lineNames(k));T=aggregate(T,dashboardAggregation.Value);y=T{:,1};y=(y-mean(y,'omitnan'))/std(y,'omitnan');plot(ax,T.Time,y,'DisplayName',name);end
   legend(ax,'Location','best');ylabel(ax,'standardisierte Abweichung');title(ax,"Gemeinsamer Vergleich – "+string(dashboardAggregation.Value));xlim(ax,[mapStart mapEnd]);xtickformat(ax,'dd.MM HH:mm');
  elseif ownAxes
   for k=1:numel(lineNames)
    row=row+1;ax=uiaxes(dashboardGrid);ax.Layout.Row=row;[T,name]=dashboardSeries(lineNames(k));T=aggregate(T,dashboardAggregation.Value);plot(ax,T.Time,T{:,1});grid(ax,'on');ylabel(ax,name,'Interpreter','none');title(ax,name+" – eigene Y-Achse");xlim(ax,[mapStart mapEnd]);xtickformat(ax,'dd.MM HH:mm');
   end
  end
  if any(isHeat)
   row=row+1;ax=uiaxes(dashboardGrid);ax.Layout.Row=row;T=aggregate(smps(:,2:end),dashboardAggregation.Value);imagesc(ax,datenum(T.Time),sizes,log10(max(T{:,:}',1)));axis(ax,'xy');set(ax,'YScale','log');xlim(ax,datenum([mapStart mapEnd]));datetick(ax,'x','dd.mm HH:MM','keeplimits');ylabel(ax,'Partikelgröße nm');title(ax,'SMPS-Größenverteilung – log10(dN/dlogDp)');cb=colorbar(ax);cb.Label.String='log10(dN/dlogDp)';
  end
 end

 function [T,name]=dashboardSeries(name)
  if name=="CPC Gesamt",T=cpc(:,{'Concentration'});elseif name=="SMPS Gesamt",T=metrics(:,{'SMPSTotal'});else,T=W(:,char(name));end
 end

 function updateCorrelation(~,~)
  idx=find(choices==string(particle.Value),1);response=responses{idx};selected=cellstr(vars.Value);if isempty(selected),return;end
  response=aggregate(response,aggregation.Value);wx=aggregate(W(:,selected),aggregation.Value);wx.Time=wx.Time+hours(lag.Value);
  A=synchronize(response,wx,'intersection');y=A.Response;X=A{:,2:end};ok=isfinite(y)&all(isfinite(X),2);y=y(ok);X=X(ok,:);t=A.Time(ok);
  if numel(y)<4,modelInfo.Text='Zu wenige gemeinsame gueltige Werte.';return;end
  r=nan(numel(selected),1);pv=r;for j=1:numel(selected),[r(j),pv(j)]=corr(X(:,j),y,'Type',method.Value);end
  summary.Data=table(string(selected(:)),r,pv,repmat(numel(y),numel(r),1),'VariableNames',{'Parameter','r','p','N'});
  Xz=(X-mean(X,1))./std(X,0,1);yz=(y-mean(y))/std(y);good=all(isfinite(Xz),2)&isfinite(yz);design=[ones(nnz(good),1) Xz(good,:)];beta=pinv(design)*yz(good);pred=design*beta;
  R2=1-sum((yz(good)-pred).^2)/sum((yz(good)-mean(yz(good))).^2);
  cla(axTime);plot(axTime,t(good),yz(good),'k','DisplayName','Messung');hold(axTime,'on');plot(axTime,t(good),pred,'r','DisplayName','Modell');legend(axTime);ylabel(axTime,'standardisiert');xtickformat(axTime,'dd.MM HH:mm');
  cla(axScatter);scatter(axScatter,X(:,1),y,18,'filled','MarkerFaceAlpha',.35);xlabel(axScatter,selected{1},'Interpreter','none');ylabel(axScatter,particle.Value);title(axScatter,sprintf('%s: r=%.3f, p=%.3g',method.Value,r(1),pv(1)));
  cla(axBars);barh(axBars,categorical(string(selected)),r);xlim(axBars,[-1 1]);xline(axBars,0,'k-');xlabel(axBars,[method.Value ' r']);
  modelInfo.Text=sprintf('Mehrvariablen-Modell: R²=%.3f, n=%d. Zusammenhang, kein Kausalnachweis.',R2,nnz(good));
 end

 function latestMap(~,~),timeSlider.Value=datenum(mapEnd);updateMap();end
 function toggleAnimation(~,~)
  if animationRunning,animationRunning=false;animationButton.Text='▶ Start';return;end
  animationRunning=true;animationButton.Text='■ Stopp';
  if timeSlider.Value>=timeSlider.Limits(2),timeSlider.Value=timeSlider.Limits(1);end
  stepDays=seconds(averagingDuration(mapAggregation.Value))/86400;
  while animationRunning&&isvalid(f)
   updateMap();drawnow;pause(.18);next=timeSlider.Value+stepDays;
   if next>timeSlider.Limits(2),animationRunning=false;animationButton.Text='▶ Start';break;end
   timeSlider.Value=next;
  end
 end
 function updateMap(~,~)
  selectedTime=datetime(timeSlider.Value,'ConvertFrom','datenum','TimeZone',site.TimeZone);[~,iw]=min(abs(weather.Time-selectedTime));wt=weather.Time(iw);
  span=averagingDuration(mapAggregation.Value);left=selectedTime-span/2;right=selectedTime+span/2;
  cval=windowMean(cpc,'Concentration',left,right,selectedTime);sval=windowMean(metrics,'SMPSTotal',left,right,selectedTime);
  wi=weather.Time>=left&weather.Time<right;if ~any(wi),wi(iw)=true;end
  ws=mean(weather.WindSpeed(wi),'omitnan');wd=mod(rad2deg(atan2(mean(sin(deg2rad(weather.WindDirection(wi))),'omitnan'),mean(cos(deg2rad(weather.WindDirection(wi))),'omitnan'))),360);
  rain=mean(weather.Precipitation(wi),'omitnan');
  legend(mapAx,'off');cla(mapAx);hold(mapAx,'on');if strcmp(basemapDrop.Value,'Satellit'),base='satellite';else,base='streets';end;try,geobasemap(mapAx,base);catch,geobasemap(mapAx,'streets');end
  period=wi&isfinite(weather.WindDirection)&weather.WindSpeed>=0.5;directions=weather.WindDirection(period);
  cla(windInset);if isempty(directions),polarplot(windInset,0,0);else,polarhistogram(windInset,deg2rad(directions),16,'Normalization','probability','FaceColor',[.15 .45 .85]);end;hold(windInset,'on');windInset.ThetaZeroLocation='top';windInset.ThetaDir='clockwise';
  rmax=max(windInset.RLim);if isfinite(wd),polarplot(windInset,deg2rad([wd wd]),[0 rmax],'m-','LineWidth',3);end;title(windInset,sprintf('Windrose %s',mapAggregation.Value),'FontSize',9);
  legendHandles=gobjects(0);legendLabels={};
  if rainCheck.Value&&isfinite(rain)&&rain>0,hRain=geoscatter(mapAx,site.WeatherStationLatitude,site.WeatherStationLongitude,180+220*min(rain,5)/5,[.1 .55 1],'filled','MarkerFaceAlpha',.28);legendHandles(end+1)=hRain;legendLabels{end+1}=sprintf('Regen %.2f mm/h',rain);end
  hSite=geoscatter(mapAx,site.Latitude,site.Longitude,95,'r','o','filled');hStation=geoscatter(mapAx,site.WeatherStationLatitude,site.WeatherStationLongitude,85,'b','^','filled');legendHandles=[legendHandles hSite hStation];legendLabels=[legendLabels {'CPC + SMPS Messpunkt',char(site.WeatherStationName)}];
  if ~isempty(airQuality)
   hAQ=geoscatter(mapAx,site.AirQualityStationLatitude,site.AirQualityStationLongitude,90,[.1 .6 .25],'d','filled');hAQ2=geoscatter(mapAx,site.AirQualitySecondaryLatitude,site.AirQualitySecondaryLongitude,82,[.95 .55 .1],'d','filled');
   legendHandles=[legendHandles hAQ hAQ2];legendLabels=[legendLabels {char(site.AirQualityStationName),char(site.AirQualitySecondaryName)}];
  end
  geolimits(mapAx,[site.Latitude-.10 site.Latitude+.10],[site.Longitude-.13 site.Longitude+.13]);legend(mapAx,legendHandles,legendLabels,'Location','southwest');title(mapAx,string(basemapDrop.Value)+" – Windrose als Inset");
  mapTime.Text='Ausgewählt: '+string(selectedTime,'dd.MM.yyyy HH:mm')+' Uhr   |   Mittel: '+string(mapAggregation.Value);cpcCard.Text=sprintf('CPC  %.0f #/cm³',cval);smpsCard.Text=sprintf('SMPS  %.0f #/cm³',sval);windCard.Text=sprintf('Wind %.2f m/s aus %.0f°  →  nach %.0f°   |   Regen %.2f mm/h',ws,wd,mod(wd+180,360),rain);
  if ~isempty(airQuality),no2=windowMean(airQuality,'ARPA_NO2',left,right,selectedTime);pm10=windowMean(airQuality,'ARPA_PM10',left,right,selectedTime);pm25=windowMean(airQuality,'ARPA_PM2_5',left,right,selectedTime);o3=windowMean(airQuality,'ARPA_O3',left,right,selectedTime);mapValues.Text=sprintf('ARPA: NO₂ %.1f | O₃ %.1f | PM₁₀ %.1f | PM₂.₅ %.1f µg/m³   ⓘ PM sind Tagesmittel.',no2,o3,pm10,pm25);end
  yyaxis(mapTrend,'left');cla(mapTrend);yyaxis(mapTrend,'right');cla(mapTrend);yyaxis(mapTrend,'left');grid(mapTrend,'on');C=aggregate(cpc(:,{'Concentration'}),mapAggregation.Value);M=aggregate(metrics(:,{'SMPSTotal'}),mapAggregation.Value);
  hold(mapTrend,'on');plot(mapTrend,C.Time,C.Concentration,'r','DisplayName','CPC');plot(mapTrend,M.Time,M.SMPSTotal,'b','DisplayName','SMPS');xline(mapTrend,selectedTime,'m','LineWidth',2,'DisplayName','Kartenzeit');ylabel(mapTrend,'Partikel #/cm³');
  if rainCheck.Value,R=aggregate(weather(:,{'Precipitation'}),mapAggregation.Value);yyaxis(mapTrend,'right');stairs(mapTrend,R.Time,R.Precipitation,'Color',[.1 .55 .9],'LineWidth',1.5,'DisplayName','Regen');ylabel(mapTrend,'Regen mm/h');end
  legend(mapTrend,'Location','best');xtickformat(mapTrend,'dd.MM HH:mm');
 end
end

function infoHeading(parent,textValue,tip)
 row=uigridlayout(parent,[1 2]);row.ColumnWidth={'1x',25};row.Padding=[0 0 0 0];uilabel(row,'Text',textValue,'FontWeight','bold');uilabel(row,'Text','ⓘ','HorizontalAlignment','center','Tooltip',tip);
end

function [choices,responses]=responseCatalog(cpc,smps,sizes,metrics) %#ok<INUSD>
 choices=["CPC Gesamt";"SMPS Gesamt (integriert)";"SMPS geometrischer Mitteldurchmesser";"SMPS geometrische Standardabweichung";"SMPS Modusdurchmesser";"SMPS Anteil <30 nm";"SMPS Anteil <100 nm";"SMPS Anteil >=100 nm"];
 responses=cell(numel(choices),1);responses{1}=rename(cpc(:,{'Concentration'}));metricNames=metrics.Properties.VariableNames;
 for k=1:numel(metricNames),responses{k+1}=rename(metrics(:,k));end
 function R=rename(R),R.Properties.VariableNames={'Response'};end
end

function W=guiWeather(weather)
 names={'Temperature','RelativeHumidity','DewPoint','PressureMSL','Precipitation','Sunshine','SolarRadiation','CloudCover','WindSpeed','WindGustSpeed','UVIndex'};names=names(ismember(names,weather.Properties.VariableNames));W=weather(:,names);
 if ismember('WindDirection',weather.Properties.VariableNames),W.WindFromEast=sin(deg2rad(weather.WindDirection));W.WindFromNorth=cos(deg2rad(weather.WindDirection));end
end

function out=aggregate(tt,label)
 switch label
  case '5 Minuten',out=retime(tt,'regular','mean','TimeStep',minutes(5));case '30 Minuten',out=retime(tt,'regular','mean','TimeStep',minutes(30));case '1 Stunde',out=retime(tt,'hourly','mean');case '12 Stunden',out=retime(tt,'regular','mean','TimeStep',hours(12));case '24 Stunden',out=retime(tt,'daily','mean');
 end
end

function d=averagingDuration(label)
 switch label,case '5 Minuten',d=minutes(5);case '30 Minuten',d=minutes(30);case '1 Stunde',d=hours(1);case '12 Stunden',d=hours(12);case '24 Stunden',d=hours(24);end
end

function v=windowMean(tt,name,left,right,target)
 ii=tt.Time>=left&tt.Time<right;
 if any(ii),v=mean(tt.(name)(ii),'omitnan');else,[~,k]=min(abs(tt.Time-target));v=tt.(name)(k);end
end

function v=nearestValue(tt,name,t)
 if isempty(tt),v=NaN;return;end;[~,i]=min(abs(tt.Time-t));v=tt.(name)(i);
end

function [la2,lo2]=destinationPoint(la,lo,bearingDeg,distanceKm)
 R=6371;d=distanceKm/R;b=deg2rad(bearingDeg);p=deg2rad(la);l=deg2rad(lo);la2=rad2deg(asin(sin(p)*cos(d)+cos(p)*sin(d)*cos(b)));lo2=rad2deg(l+atan2(sin(b)*sin(d)*cos(p),cos(d)-sin(p)*sin(deg2rad(la2))));
end
