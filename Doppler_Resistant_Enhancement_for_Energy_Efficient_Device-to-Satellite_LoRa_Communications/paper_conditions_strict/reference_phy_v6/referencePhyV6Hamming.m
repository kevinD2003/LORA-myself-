function out = referencePhyV6Hamming(values,cr,mode)
%REFERENCEPHYV6HAMMING Reference bit order and hard CR1/CR4 decoder policy.
arguments
    values (:,:) uint8
    cr (1,1) double {mustBeMember(cr,[1 4])}
    mode (1,:) char {mustBeMember(mode,{'encode','decode'})}
end
if strcmp(mode,'encode')
    if any(values(:)>15),error('ReferencePhyV6:Nibble','Nibble exceeds 15.');end
    d0=bitget(values,1);d1=bitget(values,2);d2=bitget(values,3);d3=bitget(values,4);
    if cr==1
        out=uint8(16*d0+8*d1+4*d2+2*d3+mod(d0+d1+d2+d3,2));
    else
        out=uint8(128*d0+64*d1+32*d2+16*d3+ ...
            8*mod(d0+d1+d2,2)+4*mod(d1+d2+d3,2)+ ...
            2*mod(d0+d1+d3,2)+mod(d0+d2+d3,2));
    end
else
    if any(double(values(:))>=2^(4+cr)),error('ReferencePhyV6:Codeword','Codeword exceeds its width.');end
    width=4+cr;
    d0=bitget(values,width);d1=bitget(values,width-1);
    d2=bitget(values,width-2);d3=bitget(values,width-3);
    out=uint8(d0+2*d1+4*d2+8*d3);
    if cr==4
        parity=zeros(size(values));
        for bit=1:8,parity=parity+double(bitget(values,bit));end
        s0=mod(d0+d1+d2+bitget(values,4),2);
        s1=mod(d1+d2+d3+bitget(values,3),2);
        s2=mod(d0+d1+d3+bitget(values,2),2);
        syndrome=double(s0)+2*double(s1)+4*double(s2);
        odd=mod(parity,2)~=0;
        syndromes=[5 7 3 6];
        for bit=1:4
            flip=odd & syndrome==syndromes(bit);
            out(flip)=bitxor(out(flip),uint8(2^(bit-1)));
        end
    end
end
end
