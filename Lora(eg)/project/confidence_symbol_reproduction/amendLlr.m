function llrPrime = amendLlr(llr, decodedBits, scores, mode)
%AMENDLLR Amend LLRs after soft Hamming decoding.
%
% The paper names amendLLR but does not provide a closed-form definition.
% mode="identity" keeps the measured LLRs. mode="decoded-sign" is a small
% ablation that nudges LLR signs toward the decoded codeword.

arguments
    llr (:,:) double
    decodedBits (:,:) logical
    scores (:,1) double
    mode (1,1) string = "identity"
end

switch mode
    case "identity"
        llrPrime = llr;
    case "decoded-sign"
        if ~isequal(size(llr), size(decodedBits))
            error("SenLoRa:AmendSizeMismatch", ...
                "decodedBits must have the same size as llr.");
        end

        codeLength = size(llr, 2);
        llrPrime = llr;
        for row = 1:size(llr, 1)
            signBits = 2 * double(decodedBits(row, :)) - 1;
            reliability = sqrt(max(scores(row), 0) / codeLength);
            target = signBits .* max(abs(llr(row, :)), reliability);
            llrPrime(row, :) = 0.5 * llr(row, :) + 0.5 * target;
        end
    otherwise
        error("SenLoRa:UnknownAmendMode", ...
            "Unknown amend mode: %s.", mode);
end

end

