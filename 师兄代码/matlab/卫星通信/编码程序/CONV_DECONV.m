input=[1 0 1 1 0 1 0 1 0 1 0 0 0 1 1];
n=2;k=1;L=3;
gen=[5,7];
%% 卷积码编码
trellis = poly2trellis(L,gen);
code_data = convenc(input,trellis);

%% 卷积码解码
tb = 2;
decoded = vitdec(code_data,trellis,tb,'trunc','hard');