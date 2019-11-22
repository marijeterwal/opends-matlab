function cfsOut = getSpectra_baseline(cfg, data, data_baseline, verbose)% USAGE:% --- selection of time (or for frequency: cfg.foi and cfg.df)% all times in trial included% cfg.toi = []; % selection of limits and timestep% cfg.toi = [tlim1, tlim2]; % cfg.dt = dt; % selection of time points:% cfg.toi = tlim1:dt:tlim2;% --- with and without baseline Z-scoring% the baseline has to be trial matched: for every trial, there has to be a% baseline trial in data_baseline% without baseline Z-scoring% cfsOut = getSpectra_baseline(cfg, data, [])% with baseline Z-scoring% cfg.Zscore = true;% cfsOut = getSpectra_baseline(cfg, data, data_baseline)% OUTPUT:% FieldTrip struct, if you prefer an array/cell array, than use:% cfg.FTstruct = false% TODO% implement different options for baselineif nargin < 4    verbose = false;end cfg = checkConfig(cfg, data);%% do this in parallel% % start parallel pool% c = parcluster('local');% nw = round(c.NumWorkers/2.5);% pp = parpool(nw);% don't forget to use parfor instead of for%% baselineif cfg.Zscore    % pre-all    if verbose, fprintf('Computing baseline spectra\n'); end        baselineLength = min(arrayfun(@(x) size(data_baseline.trial{x},2),1:length(data_baseline.trial)));        if cfg.outputType == 1        cfs_bl = cell(1,length(data_baseline.trial));        % cfs: {blocks}(channels x freqs x times)        for bl = 1:length(data_baseline.trial)            cfs_bl{bl} = zeros(length(cfg.channels),length(cfg.foi),baselineLength, 'single');        end    elseif cfg.outputType == 2        % cfs: (events x trials x channels x freqs x times        cfs_bl = zeros(1,length(data.trial),length(cfg.channels),length(cfg.foi),baselineLength, 'single');    end        % compute cfs    for bl = 1:length(data_baseline.trial)        for ch = 1:length(cfg.channels)            trialLength = length(data_baseline.trial{bl}(1,:));            fulltrial = cwt(data_baseline.trial{bl}(cfg.channels(ch),max(1,trialLength-baselineLength+1):trialLength), ...                cfg.scales, cfg.wavelet);                        if cfg.outputType == 1                cfs_bl{bl}(ch,:,:) = fulltrial;            elseif cfg.outputType == 2                cfs_bl(1,bl,ch,:,:) = fulltrial;            end        end    endend%% data% pre-allif verbose, fprintf('Computing spectra and Z-scoring\n'); endif cfg.outputType == 1    cfs = cell(1,length(cfg.trials));    times = cell(1,length(cfg.trials));    % cfs: {trials}(channels x freqs x times)    for tr = 1:length(cfg.trials)        ntr = cfg.trials(tr);        cfs{tr} = zeros(length(cfg.channels),length(cfg.foi),ceil(length(data.time{ntr})/cfg.DT), 'single');        times{tr} = data.time{tr}(1:cfg.DT:end);    endelseif cfg.outputType == 2    % cfs: (events x trials x channels x freqs x times    cfs = zeros(length(cfg.events),length(cfg.trials),length(cfg.channels),length(cfg.foi),length(cfg.toi), 'single');end% compute cfsfor tr = 1:length(cfg.trials)    ntr = cfg.trials(tr);        for ch = 1:length(cfg.channels)        fulltrial = cwt(data.trial{ntr}(cfg.channels(ch),:), cfg.scales, cfg.wavelet);                if cfg.Zscore            % select appropriate baseline            bltr = tr;            % or specify another selection criterium here        end                % for whole trials        if cfg.outputType == 1            if cfg.Zscore                cfs{tr}(ch,:,:) = (abs(fulltrial(:,1:cfg.DT:end)) - repmat(squeeze(nanmean(abs(cfs_bl{bltr}(ch,:,:)),3))',[1,ceil(length(data.time{tr})/cfg.DT)])) ...                    ./ repmat(squeeze(nanstd(abs(cfs_bl{bltr}(ch,:,:)),1,3))',[1,ceil(length(data.time{ntr})/cfg.DT)]);            else                cfs{tr}(ch,:,:) = fulltrial(:,1:cfg.DT:end);            end                        % for selected parts of trials        elseif cfg.outputType == 2                        % select event and downsample            for ev = 1:length(cfg.events)                if ~isfield(data, 'event')                    eventID = 1;                else                    try                    [~,eventID] = min(abs(data.time{ntr}-data.event{cfg.events(ev),ntr}));                    catch                       a=0;                     end                end                                TimeIDs = eventID + round(cfg.toi*data.fsample);                if cfg.Zscore                    cfs(ev,tr,ch,:,:) = (abs(fulltrial(:,TimeIDs)) - repmat(squeeze(nanmean(abs(cfs_bl(1,bltr,ch,:,:)),5)),[1,length(TimeIDs)]))...                        ./ repmat(squeeze(nanstd(abs(cfs_bl(1,bltr,ch,:,:)),1,5)),[1,length(TimeIDs)]);                else                    cfs(ev,tr,ch,:,:) = fulltrial(:,TimeIDs);                end            end        end    endend% delete(pp)%% convert to FT structif cfg.FTstruct    cfsOut              = rmfield(data, 'trial');    cfsOut.powspctrm    = cfs;    cfsOut.freq         = cfg.foi;    cfsOut.fsample      = 1/cfg.dt;        if cfg.outputType == 1        cfsOut.time   = times;        cfsOut.dimord = 'chan_freq_time';    elseif cfg.outputType == 2        cfsOut.time     = cfg.toi;        cfsOut.dimord = 'event_rpt_chan_freq_time';    end    else     cfsOut = cfs;endendfunction cfg = checkConfig(cfgIn, data)cfg = cfgIn;% outputType = 1: whole trial% outputType = 2: section relative to eventif ~isfield(cfg, 'wavelet'); cfg.wavelet = 'cmor8-1'; endif ~isfield(cfg, 'scales');  cfg.scales = data.fsample./cfg.foi; endif ~isfield(cfg, 'channels'); cfg.channels = 1:length(data.label); endif ~isfield(cfg, 'foi'); error('No frequencies-of-interest specified'); endif isfield(cfg, 'df') && length(cfg.foi) == 2    cfg.foi = cfg.foi(1):cfg.df:cfg.foi(2);endif ~isfield(cfg, 'Zscore'); cfg.Zscore = false; endif ~isfield(cfg, 'FTstruct'); cfg.FTstruct = true; endif ~isfield(cfg, 'trials'); cfg.trials = 1:length(data.trial); endif ~isfield(cfg, 'events'); cfg.events = 1:size(data.event,1); endif ~isfield(cfg, 'toi') || isempty(cfg.toi)%     if verbose, fprintf('Whole trial selected\n'); end    cfg.outputType = 1;    if ~isfield(cfg, 'dt'); cfg.dt = 1/data.fsample; end    cfg.DT = cfg.dt * data.fsample;else    cfg.outputType = 2;    if isfield(cfg, 'dt') && length(cfg.toi) == 2        cfg.toi = cfg.toi(1):cfg.dt:cfg.toi(2);    endendend