% //把矩阵 matrix 保存成任意后缀的文件
% //转换成 .txt 举例：mat2txt( 'filename.txt', data );
% //转换成 .corr 举例：mat2txt( 'filename.corr',data );

load("data_send.mat");
SNR=10;
data1=awgn(data1,SNR,"measured");
mat2txt('12345.txt',data1);

function back = mat2txt( file_Name, matrix ) 
fop = fopen( file_Name, 'a' );
[M,N] = size(matrix);
for m = 1:M
    for n = 1:N
        fprintf( fop, ' %s', mat2str( matrix(m,n) ) );
    end
    fprintf(fop, '\n' );
end
back = fclose( fop ) ;
end