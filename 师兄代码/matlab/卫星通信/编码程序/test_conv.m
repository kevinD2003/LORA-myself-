%% RS编码 卷积码 QPSK调制 QPSK解调　卷积码解码　RS解码
data=[randi([0 255],1,223)];
%% RS编码
[data_RS,c]=RS_CODE(data);
%% 卷积码
[data_CONV,trellis]=CONV_CODE(data_RS);
%% 将两位二进制数转换为十进制
data_frame=zeros(1,length(data_CONV)/2);
for i=1:length(data_frame)
    data_frame(i)=data_CONV(2*i)*2^(0)+data_CONV(2*i-1)*2;
end
%% QPSK调制
M=4;%QPSK
data_QPSK=pskmod(data_frame,M,pi/M);
% %此处可以加信道（衰落是、时延、多普勒）。 
%% QPSK解调
data_deQPSK=pskdemod(data_QPSK,M,pi/M);
%% 将一位十进制转换为两位二进制数
data_deQPSK_bin=0;
for i=1:length(data_deQPSK)
    if(data_deQPSK(i)==0)
        data_deQPSK_bin=[data_deQPSK_bin 0 0];
    end
    if(data_deQPSK(i)==1)
        data_deQPSK_bin=[data_deQPSK_bin 0 1];
    end
    if(data_deQPSK(i)==2)
        data_deQPSK_bin=[data_deQPSK_bin 1 0];
    end
    if(data_deQPSK(i)==3)
        data_deQPSK_bin=[data_deQPSK_bin 1 1];
    end
end
data_deQPSK_bin=data_deQPSK_bin(2:end);
%% 卷积码解码
tb = 2;
decoded_CONV = vitdec(data_deQPSK_bin,trellis,tb,'trunc','hard');%二进制
% decoded_CONV = vitdec(data_CONV,trellis,tb,'trunc','hard');%二进制

%% RS解码
decoded_CONV_dec=zeros(1,length(decoded_CONV)/8);
% 八位二进制转成十进制
for i=1:length(decoded_CONV_dec)
    nums_bin=[128 64 32 16 8 4 2 1];
    decoded_CONV_dec(i)=sum(decoded_CONV(8*i-7:8*i).*nums_bin);
    % decoded_CONV_dec(i)=decoded_CONV(8*i)*2^0+decoded_CONV(8*i-1)*2+decoded_CONV(8*i-2)*2^2+...
    %                     decoded_CONV(8*i-3)*2^3+decoded_CONV(8*i-4)*2^4+decoded_CONV(8*i-5)*2^5+...
    %                     decoded_CONV(8*i-6)*2^6+decoded_CONV(8*i-7)*2^7;
end
mes=gf(decoded_CONV_dec,8);

n=255;%码字长度
k=223;%每组符号数
[dc,nerrs,corrcode]= rsdec(mes,n,k);
decoded_RS=double(dc.x);
% [dc,nerrs,corrcode]= rsdec(c,n,k);
% isequal(dc,msgw) & isequal(corrcode,c)
% disp(['nerrs=',num2str(nerrs)]);
error=0;
for i=1:length(data)
    if(data(i)~=decoded_RS(i))
        error=error+1;
    end
end
%% RS编码，输出数据为二进制
function [data_RS_code,c]=RS_CODE(x)
%快速演示，没有具体的编码解码方法
% m=4;%每个符号比特数
n=255;%码字长度
k=223;%每组符号数
msgw=gf(x,8);
c=rsenc(msgw,n,k);%RS编码
%—————信道部分———————————
data_RS=double(c.x);
data_RS_code=0;
for i=1:length(data_RS)
    data_RS_code=[data_RS_code d2b(data_RS(i))];
end
data_RS_code=data_RS_code(2:end);

end

function data_bin=d2b(x)
data_bin=zeros(1,8);
i=1;
while(x)
    data_bin(9-i)=mod(x,2);
    i=i+1;
    x=floor(x/2);
end
end


function [data_CONV_code,trellis]=CONV_CODE(input)
n=2;k=1;L=7;% 表明是（2，1，7）编码
gen=[171,133];%编码多项式，217的编码多项式为（171，133）；
%生成卷积码
trellis = poly2trellis(L,gen);
data_CONV_code = convenc(input,trellis);
end