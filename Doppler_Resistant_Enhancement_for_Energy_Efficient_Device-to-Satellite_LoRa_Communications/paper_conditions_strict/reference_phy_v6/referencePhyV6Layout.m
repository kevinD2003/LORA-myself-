function layout = referencePhyV6Layout(cr,c)
%REFERENCEPHYV6LAYOUT First block reduced SF/CR4, then configured payload CR.
if ~ismember(cr,[1 4]) || c.sf<7 || c.sf>12 || ...
        c.payloadBytes<2 || c.payloadBytes>255 || c.payloadBytes~=fix(c.payloadBytes)
    error('ReferencePhyV6:Layout','Unsupported reference PHY format.');
end
switch c.ldroMode
    case 'auto',ldro=c.symbolDurationSec*1e3>16;
    case 'on',ldro=true;
    case 'off',ldro=false;
    otherwise,error('ReferencePhyV6:Ldro','Unknown LDRO mode.');
end
totalNibbles=2*c.payloadBytes+5*double(c.explicitHeader)+4*double(c.hasCrc);
firstRows=c.sf-2;laterRows=c.sf-2*double(ldro);
laterBlocks=max(ceil((totalNibbles-firstRows)/laterRows),0);
rows=[firstRows repmat(laterRows,1,laterBlocks)];
rates=[4 repmat(cr,1,laterBlocks)];
widths=4+rates;reduced=[true repmat(ldro,1,laterBlocks)];
wordStarts=[1 1+cumsum(rows(1:end-1))];symbolStarts=[1 1+cumsum(widths(1:end-1))];
actualCounts=max(min(rows,totalNibbles-wordStarts+1),0);
symbolCount=sum(widths);
% Eight pilots, two sync upchirps, and 2.25 downchirp delimiter symbols.
observationIndices=[(0:c.preambleSymbolCount+1).'; ...
    c.preambleSymbolCount+2+c.syncDownchirpSymbols+(0:symbolCount-1).'];
onAirSymbols=c.preambleSymbolCount+2+c.syncDownchirpSymbols+symbolCount;
layout=struct('cr',cr,'ldro',ldro,'totalNibbles',totalNibbles, ...
    'rows',rows,'rates',rates,'widths',widths,'reduced',reduced, ...
    'wordStarts',wordStarts,'symbolStarts',symbolStarts,'actualCounts',actualCounts, ...
    'symbolCount',symbolCount,'wordCount',sum(rows), ...
    'codedBitsPerPacket',sum(actualCounts.*widths), ...
    'observationIndices',observationIndices,'onAirSymbols',onAirSymbols, ...
    'durationSec',(onAirSymbols+c.interFrameSilenceSymbols)*c.symbolDurationSec);
end
