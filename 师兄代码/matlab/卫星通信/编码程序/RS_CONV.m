data=[randi([0 255],1,223)];
%% RS编码
data_RS=RS_CODE(data);
%% 卷积码
data_CONV=CONV_CODE(data_RS);
%% 将两位二进制数转换为十进制
data_frame=zeros(1,length(data_CONV)/2);
for i=1:length(data_frame)
    data_frame(i)=data_CONV(2*i)*2^(0)+data_CONV(2*i-1)*2;
end
%% QPSK调制


%% RS编码，输出数据为二进制
function data_RS_code=RS_CODE(x)
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


function data_CONV_code=CONV_CODE(input)
n=2;k=1;L=7;% 表明是（2，1，7）编码
gen=[171,133];%编码多项式，217的编码多项式为（171，133）；
%生成卷积码
trellis = poly2trellis(L,gen);
data_CONV_code = convenc(input,trellis);
end