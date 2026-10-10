function rx = referenceSoftDecode(iq,prediction,cr,c,softWindow)
%REFERENCESOFTDECODE Standard soft PHY after causal, constant-per-symbol CFO.
% LR still uses the frozen Hann/4x/centroid front end and hard feedback.
% The auxiliary path evaluates N integer candidate bins; window is explicit.
arguments
    iq (:,:) double
    prediction (:,:) double
    cr (1,1) double
    c (1,1) struct
    softWindow (1,:) char {mustBeMember(softWindow,{'reference-rectangular','paper-hann'})} = 'reference-rectangular'
end
layout=referencePhyV6Layout(cr,c);observations=numel(layout.observationIndices);
replicates=size(prediction,2);m=2^c.sf;
if size(prediction,1)~=observations || replicates==0 || ...
        ~isequal(size(iq),[observations*replicates m]) || ...
        any(~isfinite(real(iq(:))) | ~isfinite(imag(iq(:))))
    error('ReferenceSoft:IQ','Expected complete, finite v6 observations.');
end
rows=c.preambleSymbolCount+2+(1:layout.symbolCount);
frequency=reshape(prediction(rows,:),1,[]);
if any(~isfinite(frequency)),error('ReferenceSoft:Prediction','Invalid data-symbol prediction.');end
source=rows(:)+(0:replicates-1)*observations;
samples=iq(source(:),:).';down=conj(dreModulateSymbols(0,c)).';
if strcmp(softWindow,'paper-hann')
    % Exact same periodic Hann as the frozen paper front end, no tuned width.
    samples=samples.*(0.5-0.5*cos(2*pi*(0:m-1).'/m));
end
rotation=exp(-1i*2*pi*(0:m-1).'*mod(frequency,m)/m);
power=abs(fft(samples.*down.*rotation,m,1)).^2;
words=zeros(layout.wordCount,replicates,'uint8');data=zeros(size(words),'uint8');
clippedSymbols=false(layout.symbolCount,replicates);
symbolLlr=zeros(c.sf,layout.symbolCount,replicates);
% Batch independent symbol likelihoods by rate without changing their order.
for reduced=unique(layout.reduced)
    si=[];
    for block=find(layout.reduced==reduced)
        si=[si layout.symbolStarts(block)+(0:layout.widths(block)-1)]; %#ok<AGROW>
    end
    columns=si(:)+(0:replicates-1)*layout.symbolCount;
    selectedPower=power;
    if numel(columns)~=size(power,2),selectedPower=power(:,columns(:));end
    [bits,clipped]=referenceSoftLlr(selectedPower,reduced);
    sfApp=c.sf-2*double(reduced);
    symbolLlr(c.sf-sfApp+(1:sfApp),si,:)=reshape(bits,sfApp,numel(si),replicates);
    clippedSymbols(si,:)=reshape(clipped,numel(si),replicates);
end
for block=1:numel(layout.rows)
    width=layout.widths(block);sfApp=layout.rows(block);
    wi=layout.wordStarts(block)+(0:sfApp-1);si=layout.symbolStarts(block)+(0:width-1);
    bits=symbolLlr(c.sf-sfApp+(1:sfApp),si,:);
    wordLlr=zeros(width,sfApp,replicates);
    for column=0:width-1
        for row=0:sfApp-1
            target=mod(column-row-1,sfApp)+1;
            wordLlr(column+1,target,:)=bits(row+1,column+1,:);
            value=reshape(bits(row+1,column+1,:)>0,1,replicates);
            words(wi(target),:)=bitor(words(wi(target),:),bitshift(uint8(value),width-column-1));
        end
    end
    chosen=referenceSoftHamming(reshape(wordLlr,width,[]),layout.rates(block));
    data(wi,:)=reshape(chosen,sfApp,replicates);
end
rx=referenceSoftBytes(data,words,cr,c);
rx.softFeedbackIntoLR=false;rx.clippedSymbols=clippedSymbols;
rx.decodedNibbles=data(1:layout.totalNibbles,:);
rx.softWindow=softWindow;
end
