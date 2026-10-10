function value = exp1CellId(orbitStartSec,snrDb)
%EXP1CELLID Filesystem-safe stable cell identity.

orbitText = sprintf('%+07.1f',orbitStartSec);
snrText = sprintf('%+07.2f',snrDb);
orbitText = strrep(strrep(strrep(orbitText,'+','p'),'-','m'),'.','d');
snrText = strrep(strrep(strrep(snrText,'+','p'),'-','m'),'.','d');
value = sprintf('orbit_%s_snr_%s',orbitText,snrText);
end

