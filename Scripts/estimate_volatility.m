% [INPUT]
% data = A numeric t-by-6 table containing the following time series:
%         - Date (the dates of the observations)
%         - Open (the opening prices)
%         - High (the highest prices)
%         - Low (the lowest prices)
%         - Close (the closing prices)
%         - Return (the log returns)
% est  = A string representing the historical volatility estimator, its value can be one of the following:
%         - CC (the traditional Close-to-Close estimator)
%         - CCD (a variant of the previous estimator that uses demeaned returns)
%         - GK (the estimator proposed by Garman & Klass, 1980)
%         - GKYZ (a extension of the previous estimator proposed by Yang & Zhang, 2000)
%         - HT (the estimator proposed by Hodges & Tompkins, 2002)
%         - M (the estimator proposed by Meilijson, 2009)
%         - P (the estimator proposed by Parkinson, 1980)
%         - RS (the estimator proposed by Rogers & Satchell, 1991)
%         - YZ (the estimator proposed by Yang & Zhang, 2000)
% bw   = An integer representing he bandwidth (dimension) of each rolling window.
% cln  = A boolean that indicates whether to remove the NaN values at the beginning of the result (optional, default=true).
%
% [OUTPUT]
% vol  = A vector of floats containing the estimated historical volatility.

function vol = estimate_volatility(varargin)

    persistent p;

    if (isempty(p))
        p = inputParser();
        p.addRequired('data',@(x)validateattributes(x,{'table'},{'2d','nonempty','ncols',6}));
        p.addRequired('est',@(x)any(validatestring(x,{'CC','CCD','GK','GKYZ','HT','M','P','RS','YZ'})));
        p.addRequired('bw',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',2}));
        p.addOptional('cln',true,@(x)validateattributes(x,{'logical'},{'scalar'}));
    end

    p.parse(varargin{:});
    
    res = p.Results;
    data = res.data;
    est = res.est;
    bw = res.bw;
    cln = res.cln;

    t = size(data,1);
    
    if (bw >= t)
        error('The number of observations must be greater than the bandwidth.');
    end
    
    vol = estimate_volatility_internal(data,t,est,bw,cln);

end

function vol = estimate_volatility_internal(data,t,est,bw,cln)

    switch (est)
        case 'CC'
            res = data.Return .^ 2;
            param = sqrt(252 / (bw - 1));
            fun = @(x) param * sqrt(sum(x));
        case 'CCD'
            res = (data.Return - nanmean(data.Return)) .^ 2;
            param = sqrt(252 / (bw - 1));
            fun = @(x) param * sqrt(sum(x));
        case 'GK'
            co = log(data.Close ./ data.Open);
            hl = log(data.High ./ data.Low);
            res = 0.5 * (hl .^ 2) - ((2 * log(2)) - 1) * (co .^ 2);
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));
        case 'GKYZ'
            co = log(data.Close ./ data.Open);
            hl = log(data.High ./ data.Low);
            oc = log(data.Open ./ [NaN; data.Close(1:end-1)]) .^ 2;
            res = oc + 0.5 * (hl .^ 2) - ((2 * log(2)) - 1) * (co .^ 2);
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));
        case 'HT'
            res = data.Return;
            dif = t - bw;
            param = sqrt(252 / (1 - (bw / dif) + (((bw ^ 2) - 1) / (3 * (dif ^ 2)))));
            fun = @(x) param * std(x);
        case 'M'
            co = log(data.Close ./ data.Open);
            ho = log(data.High ./ data.Open);
            lo = log(data.Low ./ data.Open);
            s2 = log(data.Close ./ data.Open) .^ 2;
            co_neg = co < 0;
            co_swi = -1 .* co;
            ho_swi = ho;
            ho_swi(co_neg) = -1 .* lo(co_neg);
            lo_swi = lo;          
            lo_swi(co_neg) = -1 .* ho(co_neg);
            s1 = 2 .* (((ho_swi - co_swi) .^ 2) + (lo_swi .^ 2));
            s3 = 2 .* ((ho_swi - co_swi - lo_swi) .* co_swi);
            s4 = -1 .* (((ho_swi - co_swi) .* lo_swi) ./ ((2 * log(2)) - 1.25));
            res = (0.273520 * s1) + (0.160358 * s2) + (0.365212 * s3) + (0.200910 * s4);
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));
        case 'P'
            % Parkinson High-Low volatility. Validated against the TTR implementation. 
            % For formula see: https://www.rdocumentation.org/packages/TTR/versions/0.23-2/topics/volatility
            res = log(data.High ./ data.Low) .^ 2;
            param = sqrt(252 / (bw * 4 * log(2)));
            fun = @(x) param * sqrt(sum(x));
        case 'RS'
            co = log(data.Close ./ data.Open);
            ho = log(data.High ./ data.Open);
            lo = log(data.Low ./ data.Open);
            res = (ho .* (ho - co)) + (lo .* (lo - co));
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));
        case 'YZ'
            %% ---------------------------------------------------
            % COMPUTE YANG-ZHANG VOLATILITY
            
            % YZ volatility is a weighted sum of 
            % sigma_o = Open/Close, 
            % simga_c = Close/Open,  
            % sigma_rs = Roger-Satchell volatility. 
            % The calculation was validated against the R - TTR package.
            % https://www.rdocumentation.org/packages/TTR/versions/0.23-2/topics/volatility
            
            co = log(data.Close ./ data.Open);
            ho = log(data.High ./ data.Open);
            lo = log(data.Low ./ data.Open);
            hc = log(data.High ./ data.Close); 
            lc = log(data.Low ./ data.Close);
            
            % Create matrix with columns: log(Open/Close), log(Close/Open)
            % and Roger-Satchel values for the full time window.
            res = [(log(data.Open ./ [NaN; data.Close(1:end-1)])) ...
                  (co) ((ho .* hc) + (lo .* lc))];
            
            % Assign k parameter. The value is equivalent to alpha = 1.34.
            k = 0.34 / (1.34 + ((bw + 1) / (bw - 1)));
            
            % Assign the vector of weights for each volatility type.
            param1 = [1 k (1 - k)];
            
            % Define two 'summary' functions to be applied to the 
            % rolling windows.

            % Weighted variance is applied to sigma_o and sigma_c.
            fun_co = @(x)  252 .* var(x);
            
            % A weighted sum is applied to sigma_rs.
            fun_rs = @(x)  252/bw .* sum(x);
    end
    %% ---------------------------------------------------
    % COMPUTE VOLATILITY ON ROLLING WINDOWS

    % Get the rolling windows for each volatility measure.
    win = get_rolling_windows(res,bw);
    
    % The number of rolling windows.
    win_len = length(win);

    % Difference between length of series and number of rolling windows.
    win_dif = t - win_len;
   
    % Initialize the volatility vector.
    vol = NaN(t,1);

    % In the switch block above, each case block (other than Y-Z) defines
    % a single "summary" function (fun). The Y-Z volatility calculation requires
    % two 'summary' functions, which in turn requires the additional conditional 
    % block below.

    % Is Yang-Zhang volatility being calculated?
    if(~strcmp(est, 'YZ'))
    % YES: This is not YZ so calculate the rolling volatility using 
    % the "summary" function (fun) 
   
      for i = 1:win_len
          vol(i+win_dif) = fun(win{i});
      end
    % NO : this is Y-Z volatility being calculated  
    else
   
      for i = 1:win_len

        % Compute the weighted volatilities using the two "summary" functions.
        weighted_vol = param1 .* [fun_co(win{i}(:, 1:2)) fun_rs(win{i}(:, 3))];
        
        % The square-root of the sum is approximately the 
        % standard annual percent deviation.
        vol(i+win_dif) = sqrt(sum(weighted_vol));
      end
    end % if(~YZ) 

    % Remove NaN values.
    if (cln)
        vol(isnan(vol)) = [];
    end

end