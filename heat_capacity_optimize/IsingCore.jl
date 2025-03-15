module IsingCore

using Random, LinearAlgebra, Statistics, StatsBase, Printf, Distributions
using StochasticAD

function initial_state(N)
    state = ones(N, N)
    return state
end

function metropolis_sampler(config, beta, N)
    range_i = shuffle!(collect(1:N))
    range_j = shuffle!(collect(1:N))
    for i in range_i
        for j in range_j
            s = config[i, j]
            nb = config[mod1(i + 1, N), j] + config[i, mod1(j + 1, N)] +
                 config[mod1(i - 1, N), j] + config[i, mod1(j - 1, N)]
            cost = 2s * nb

            flip_prob = min(1.0, exp(-cost * beta))
            coin = rand(Bernoulli(flip_prob))
            config[i, j] = [s, -s][1+coin]
        end
    end

    return config
end

function independent_sampler(config, beta, N)
    range_i = shuffle!(collect(1:N))
    range_j = shuffle!(collect(1:N))
    for i in range_i
        for j in range_j
            s = config[i, j]
            s2 = rand((-1.0, 1.0))
            nb = config[mod1(i + 1, N), j] + config[i, mod1(j + 1, N)] +
                 config[mod1(i - 1, N), j] + config[i, mod1(j - 1, N)]
            cost = (s - s2) * nb
            flip_prob = min(1.0, exp(-cost * beta))
            coin = rand(Bernoulli(flip_prob))
            config[i, j] = [s, s2][1 + coin]
        end
    end

    return config
end

function calc_energy(config, N)
    energy = 0.0

    for i in 1:N
        for j in 1:N
            S = config[i, j]
            nb = config[mod1(i + 1, N), j] + config[i, mod1(j + 1, N)] +
                 config[mod1(i - 1, N), j] + config[i, mod1(j - 1, N)]
            energy -= nb * S
        end
    end
    return energy / 2.0
end

function calc_mag(config)
    mag = sum(config) / length(config)^2
    return mag
end

function ising_model(N, T, _config, move)
    eqSteps = 10^2
    mcSteps = 10^3
    
    E1 = M1 = E2 = M2 = 0
    iT = 1.0 / T
    iT2 = iT * iT
    
    config = _config + _config * T * 0
    
    for _ in 1:eqSteps
        config = move(config, iT, N)
    end
    
    for _ in 1:mcSteps
        config = move(config, iT, N)
        ene = calc_energy(config, N)
        mag = abs(calc_mag(config))
        
        E1 += StochasticAD.smooth_triple(ene)
        M1 += StochasticAD.smooth_triple(mag)
        E2 += StochasticAD.smooth_triple(ene^2)
        M2 += StochasticAD.smooth_triple(mag^2)
    end

    E = E1 / mcSteps
    M = M1 / mcSteps
    C = (E2 / mcSteps - (E1 / mcSteps)^2) * iT2
    X = (M2 / mcSteps - (M1 / mcSteps)^2) * iT
    
    return E, M, C, X
end

function ising_model_remc(N, T, _config, move)
    eqSteps = 10^2
    mcSteps = 10^3
    
    E1 = M1 = E2 = M2 = 0
    iT = 1.0 / T
    iT2 = iT * iT

    T_low = T * 0.8
    T_high = T * 1.2
    T_replicas = [T_high, T, T_low]
    betas = 1.0 ./ T_replicas
    num_replicas = length(betas)

    # init
    configs_tmp = [_config + _config * T_replicas[i] * 0 for i in eachindex(T_replicas)]
    configs = [copy(configs_tmp[i]) for i in 1:length(T_replicas)]

    for _ in 1:eqSteps
        for r in 1:num_replicas
            configs[r] = move(configs[r], betas[r], N)
        end
    end

    for step in 1:mcSteps
        for r in 1:num_replicas
            configs[r] = move(configs[r], betas[r], N)
        end

        config_target = configs[2]
        ene = calc_energy(config_target, N)
        mag = abs(calc_mag(config_target))
        E1 += StochasticAD.smooth_triple(ene)
        M1 += StochasticAD.smooth_triple(mag)
        E2 += StochasticAD.smooth_triple(ene^2)
        M2 += StochasticAD.smooth_triple(mag^2)
    
        # レプリカ交換（5 monte carlo stepおき）
        if step % 5 == 0
            for r in 1:(num_replicas - 1)
                config1 = configs[r]
                config2 = configs[r + 1]
                beta1 = betas[r]
                beta2 = betas[r + 1]
                energy1 = calc_energy(config1, N)
                energy2 = calc_energy(config2, N)
        
                delta_beta = beta2 - beta1
                delta_energy = energy2 - energy1
                exchange_prob = min(1.0, exp(delta_beta * delta_energy))
                exchange_prob_val = StochasticAD.value(exchange_prob)
        
                if rand() < exchange_prob_val
                    configs[r], configs[r + 1] = configs[r + 1], configs[r]
                end
            end
        end
    end

    E = E1 / mcSteps
    M = M1 / mcSteps
    C = (E2 / mcSteps - E^2) * iT2
    X = (M2 / mcSteps - M^2) * iT

    return E, M, C, X
end

function ising_model_manyT(N, move, T=nothing)
    T_min = 0.05
    T_max = 10.0

    (T === nothing) && (T = range(T_min, T_max, length=50))
    nt = length(T)

    E, M, C, X = zeros(nt), zeros(nt), zeros(nt), zeros(nt)

    config = initial_state(N)
    for tt in 1:nt
        # println(T[tt])
        Et, Mt, Ct, Xt = ising_model_remc(N, T[tt], config, move)
        E[tt] = Et
        M[tt] = Mt
        C[tt] = Ct
        X[tt] = Xt
    end
    return T, E, M, C, X
end

export initial_state, metropolis_sampler, independent_sampler, calc_energy, calc_mag, ising_model, ising_model_remc, ising_model_manyT

end