function metrics=computeSMPSMetrics(smps,sizes)
% Kennwerte aus dN/dlogDp. Integration erfolgt ueber log10(Dp)-Binbreiten.
if isempty(smps),metrics=timetable;return;end
X=max(smps{:,2:end},0);ld=log10(sizes(:)');
edges=[ld(1)-(ld(2)-ld(1))/2,(ld(1:end-1)+ld(2:end))/2,ld(end)+(ld(end)-ld(end-1))/2];
dlog=diff(edges);N=X.*dlog;total=sum(N,2,'omitnan');safe=max(total,eps);
lnD=log(sizes(:)');gmd=exp(sum(N.*lnD,2,'omitnan')./safe);
gsd=exp(sqrt(sum(N.*(lnD-log(gmd)).^2,2,'omitnan')./safe));
[~,imode]=max(X,[],2);modeDp=sizes(imode)';
nuc=sum(N(:,sizes<30),2,'omitnan')./safe;ufp=sum(N(:,sizes<100),2,'omitnan')./safe;acc=sum(N(:,sizes>=100),2,'omitnan')./safe;
metrics=timetable(smps.Time,total,gmd,gsd,modeDp,nuc,ufp,acc, ...
 'VariableNames',{'SMPSTotal','GeometricMeanDiameter','GeometricStdDev','ModeDiameter','FractionBelow30nm','FractionBelow100nm','FractionAbove100nm'});
end
