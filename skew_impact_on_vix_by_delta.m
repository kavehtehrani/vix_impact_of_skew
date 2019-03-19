%% Kaveh Tehrani

clc; clear; close all; load_constants;

fig_iv              = figure; hold on;
var_k               = NaN(3, 1);

colors              = { 'r', 'b', 'g' };
for idx_surface = 1:3
    opt_set         = struct();
    opt_set.delta   = linspace(.9, .1, 50)';
    opt_set.k       = NaN(size(opt_set.delta));
    s0              = 50;
    opt_set.c_bid   = NaN(size(opt_set.k));
    opt_set.c_ask   = NaN(size(opt_set.k));
    opt_set.p_bid   = NaN(size(opt_set.k));
    opt_set.p_ask   = NaN(size(opt_set.k));
    opt_set.ttm     = NaN(size(opt_set.k));
    
    opt_set.rd      = 0;
    opt_set.rf      = 0;
    opt_set.ttm     = 1/12;
    
    if idx_surface == 1
        opt_set.sigma   = repmat(.25, size(opt_set.k));
    elseif idx_surface == 2
        opt_set.sigma   = (linspace(0, .62, length(opt_set.k))-.4)'.^2 +.21;
    elseif idx_surface == 3
        opt_set.sigma   = (linspace(.4, .7, length(opt_set.k)))'.^2-.07;
    else
    end
    
 
    for idx_k = 1:length(opt_set.k)
        opt_set.k(idx_k)        = bs_option.calc_strike_by_delta('c', opt_set.delta(idx_k), s0, opt_set.rd, opt_set.ttm, opt_set.sigma(idx_k), opt_set.rf);

        [ c, p ]                = bs_option.calc_premium(s0, opt_set.k(idx_k), opt_set.rd, opt_set.ttm, opt_set.sigma(idx_k), opt_set.rf);
        delta                   = bs_option.calc_delta(s0, opt_set.k(idx_k), opt_set.rd, opt_set.ttm, opt_set.sigma(idx_k), opt_set.rf, 'c');
        opt_set.delta(idx_k)    = delta;
        
        opt_set.c_bid(idx_k)    = c;
        opt_set.c_ask(idx_k)    = c;
        
        opt_set.p_bid(idx_k)    = p;
        opt_set.p_ask(idx_k)    = p;
    end
    
    [ var_strike, calc_table, contributions ] = calc_var_strike_from_options(opt_set);
    var_k(idx_surface)          = sqrt(var_strike);
    disp(sqrt(var_strike))
    
    d_c                 = NaN(size(calc_table, 1), 2);
    for idx_k = 1:size(d_c, 1)
        d_c(idx_k, 1)   = opt_set.delta(opt_set.k == calc_table(idx_k, 3));
    end
    d_c(:, 2)           = contributions./sum(contributions);
    
    % plot implied vol curve
    figure(fig_iv);
    l = plot(d_c(:, 1), opt_set.sigma*100, 'color', colors{idx_surface});
    
    % contribution to vix by delta
    figure;
    b = bar(d_c(:, 1), d_c(:, 2)*100);
    b.FaceColor = colors{idx_surface};
    ax = gca();
    ax.XLim = [ 0 1 ];
    change_ax_labels_to_deltas();
    ax.XDir = 'reverse'; grid minor;
    ylabel('Contribution to Var Strike');
    xlabel('Delta');
    ytickformat('%.1f%%')
    
end

figure(fig_iv);
ax = gca();
ax.XLim = [ 0 1 ];
change_ax_labels_to_deltas();
ax.XDir = 'reverse'; grid minor;
ylabel('Implied Volatility');
xlabel('Delta');
ytickformat('%d%%')
