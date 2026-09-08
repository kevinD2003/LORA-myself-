%% 十进制转二进制，输入要小于255
x=5;
data_tmp=zeros(1,8);
i=1;
while(x)
    data_tmp(9-i)=mod(x,2);
    i=i+1;
    x=floor(x/2);
end

% data=zeros(1,8);
% for i=1:8
%     data(i)=data_tmp(9-i);
% end