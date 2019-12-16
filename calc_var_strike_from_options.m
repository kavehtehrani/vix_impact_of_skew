%% this option calculates the variance swap strike from a set options
% methodology based on CBOE's VIX calculation at
% https://www.cboe.com/micro/vix/vixwhite.pdf

% Kaveh Tehrani

function [ var_strike, calc_table, contributions ] = calc_var_strike_from_options( opt_set )
    if any(structfun(@(x) size(x, 2), opt_set) ~= 1 ) 
        error('opt_set inputs need to be all in columns')
    end
    
    % remove all nans
    opt_set             = remove_opt_nans(opt_set);
    
    if ~issorted(opt_set.k) || (opt_set.k(end) < opt_set.k(1))
        error('need to pass in strictly increasing set of strikes.');
    end
    
    % calculate mid quotes
    opt_set.c_mid       = mean([ opt_set.c_bid, opt_set.c_ask] , 2);
    opt_set.p_mid       = mean([ opt_set.p_bid, opt_set.p_ask] , 2);
    
    % find forward price
    diff_k              = abs(opt_set.c_mid - opt_set.p_mid);
    [ ~, idx ]          = min(diff_k);
    k_fwd               = opt_set.k(idx);
    forward             = k_fwd + exp(opt_set.rd*opt_set.ttm)*(opt_set.c_mid(idx) - opt_set.p_mid(idx));
    k0                  = opt_set.k(find(opt_set.k < forward, 1, 'last'));
    if isempty(k0)
        error('could not find k0.');
    end
    
    % discard options that are in-the-money, have no bids, or further out-of-the-money options have two consecutive zero bids
    idx_valid_calls     = opt_set.k > forward;
    idx_valid_puts      = opt_set.k < forward;
    for idx_cur = 1:length(opt_set.k)
        % no bid
        if opt_set.c_bid(idx_cur) == 0,         idx_valid_calls(idx_cur) = 0;               end
        if opt_set.p_bid(idx_cur) == 0,         idx_valid_puts(idx_cur) = 0;                end
        
        % two consecutive zero bids, discard all options before it
        if (idx_cur >= 2) && (opt_set.p_bid(idx_cur) == 0) && (opt_set.p_bid(idx_cur-1) == 0)
            idx_valid_puts(idx_cur:-1:1)        = 0;
        end
        
        if (idx_cur < length(opt_set.k)) && (opt_set.c_bid(idx_cur) == 0) && (opt_set.c_bid(idx_cur+1) == 0)
            idx_valid_calls(idx_cur:end)        = 0;
        end
    end
    
    % only one call or one put is ever valid
    if any(idx_valid_calls & idx_valid_puts)
        error('overlapping puts and call encountered.');
    end
    
    calc_table      = [ find(idx_valid_puts)    -ones(sum(idx_valid_puts), 1)   opt_set.k(idx_valid_puts)   opt_set.p_mid(idx_valid_puts);
        find(idx_valid_calls)    ones(sum(idx_valid_calls), 1)   opt_set.k(idx_valid_calls)   opt_set.c_mid(idx_valid_calls); ];
    % k0 is a special case, average of call and puts
    idx_k0          = find(opt_set.k == k0);
    calc_table(calc_table(:, 3) == k0, 4)       = (opt_set.p_mid(idx_k0) + opt_set.c_mid(idx_k0)) / 2;
    
    delta_k         = [ calc_table(2, 3)-calc_table(1, 3);   ...
        ( calc_table(3:end, 3) - calc_table(1:end-2, 3) ) / 2;    ...
        calc_table(end, 3)-calc_table(end-1, 3) ];
    
    % contribution of each strike to variance strike
    contributions   = vix_contribution(delta_k, calc_table(:, 3), opt_set.rd, opt_set.ttm, calc_table(:, 4));
    
    first_term      = (2/opt_set.ttm) * sum(contributions);
    second_term     = (1/opt_set.ttm) * (forward/k0-1)^2;
    
    var_strike      = first_term - second_term;
    if var_strike < 0
        error('no arbitrage condition violation: negative variance encountered.');
    end
end

function opt_set = remove_opt_row(opt_set, idx_row)
    opt_set.k(idx_row)          = [];
    
    opt_set.c_bid(idx_row)      = [];
    opt_set.c_ask(idx_row)      = [];
    
    opt_set.p_bid(idx_row)      = [];
    opt_set.p_ask(idx_row)      = [];
end

function opt_set = remove_opt_nans(opt_set)
    nan_idx                     = isnan(opt_set.c_bid) & isnan(opt_set.c_ask) & isnan(opt_set.p_bid) & isnan(opt_set.p_ask);
    opt_set                     = remove_opt_row(opt_set, nan_idx);
end

function k_c = vix_contribution(delta_k, k, rf, ttm, mid_quote)
    k_c                         = (delta_k./(k.^2)) .* exp(rf.*ttm) .* mid_quote;
end
