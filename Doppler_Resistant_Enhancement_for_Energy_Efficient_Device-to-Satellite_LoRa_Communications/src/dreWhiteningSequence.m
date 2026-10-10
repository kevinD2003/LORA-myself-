function sequence = dreWhiteningSequence(lengthBits)
%DREWHITENINGSEQUENCE Deterministic x^9+x^5+1 whitening sequence.

state = true(1,9);
sequence = false(lengthBits,1);
for k = 1:lengthBits
    sequence(k) = state(9);
    feedback = xor(state(9),state(5));
    state = [feedback state(1:8)]; %#ok<AGROW>
end
end

