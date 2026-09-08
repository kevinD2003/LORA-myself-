function confidence = symbolConfidence(llrSymbols)
%SYMBOLCONFIDENCE Sum of squared bit LLRs per symbol.

arguments
    llrSymbols (:,:) double
end

confidence = sum(abs(llrSymbols) .^ 2, 2);

end

