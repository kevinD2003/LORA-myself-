function data = referenceSoftHamming(llr,cr)
%REFERENCESOFTHAMMING Pinned gr-lora_sdr ML table and first-maximum tie policy.
% Algorithm provenance: GPL-3.0 gr-lora_sdr 31243b0ac9cc..., hamming_dec_impl.cc.
arguments
    llr (:,:) double
    cr (1,1) double {mustBeMember(cr,[1 4])}
end
width=4+cr;
if size(llr,1)~=width || isempty(llr) || any(~isfinite(llr(:)))
    error('ReferenceSoft:LLR','Expected finite MSB-first word LLRs.');
end
ham8=uint8([0 23 45 58 78 89 99 116 139 156 166 177 197 210 232 255]);
lookup=ham8;
if cr==1,lookup=uint8([0 24 40 48 72 80 96 120 136 144 160 184 192 216 232 240]);end
words=bitshift(lookup,-(8-width));signs=zeros(16,width);
for bit=1:width,signs(:,bit)=2*double(bitget(words,width-bit+1)).'-1;end
scores=zeros(16,size(llr,2));
for bit=1:width,scores=scores+signs(:,bit).*llr(bit,:);end
[~,chosen]=max(scores,[],1); % literal bit-sum and LUT order, including ties
high=bitshift(ham8(chosen),-4);data=zeros(1,numel(chosen),'uint8');
for bit=1:4,data=bitor(data,bitshift(uint8(bitget(high,bit)),4-bit));end
end
