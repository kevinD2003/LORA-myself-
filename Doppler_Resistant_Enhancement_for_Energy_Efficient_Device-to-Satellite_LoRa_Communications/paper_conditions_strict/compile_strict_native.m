function build = compile_strict_native()
%COMPILE_STRICT_NATIVE Build the direct-IQ kernel and record exact binaries.
folder=strictPaperSetup();
source=fullfile(folder,'strictPaperNativeCentroids.cpp');
mex('-R2018a','COMPFLAGS=$COMPFLAGS /O2 /openmp', ...
    '-outdir',folder,source);
binary=fullfile(folder,['strictPaperNativeCentroids.' mexext]);
build=struct('sourceSha256',localHash(source),'binarySha256',localHash(binary), ...
    'matlabVersion',version,'compilerFlags','/O2 /openmp', ...
    'samplePrecision','double','directSampleLevelIQ',true);
file=fopen(fullfile(folder,'native_build.json'),'w','n','UTF-8');
closer=onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(build,'PrettyPrint',true));
end

function hash=localHash(path)
file=fopen(path,'rb');closer=onCleanup(@()fclose(file));bytes=fread(file,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
raw=typecast(digest.digest(),'uint8');hash=lower(reshape(dec2hex(raw,2).',1,[]));
end
