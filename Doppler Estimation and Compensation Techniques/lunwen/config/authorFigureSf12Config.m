function cfg = authorFigureSf12Config()
%AUTHORFIGURESF12CONFIG Configuration transcribed from author arXiv source.

cfg = paperSf12Config();
cfg.experimentName = "author_figure_sf12_midamble_point";
cfg.channel.model = "awgn_only";
cfg.frame.midambleSpacingDataSymbols = 1;
cfg.plot.noDopplerLabel = "AWGN (No Doppler)";
cfg.paper.midamblePointToaS = 1.843200;
cfg.provenance.profile = "author_arxiv_figure_source";
cfg.provenance.sourceFile = "tmp/references/paper_arxiv_source/main.tex";
cfg.provenance.rationale = ...
    "Source lines 500 and 530 specify AWGN+Doppler and n_int=1.";
cfg.provenance.fittedOrTuned = false;
end
