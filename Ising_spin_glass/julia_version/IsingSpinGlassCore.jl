module IsingSpinGlassCore

using Random, LinearAlgebra, Statistics, StatsBase, Printf, Distributions

function initial_state(L)
    state = (ones(L, L, L), ones(L, L, L))
    return state
end

function initial_couplings(L; dist=:uniform, J=1.0)
    if dist == :gaussian
        Jx = randn(L, L, L)
        Jy = randn(L, L, L)
        Jz = randn(L, L, L)
    elseif dist == :uniform
        Jx = [rand() < 0.5 ? J : -J for i in 1:L, j in 1:L, k in 1:L]
        Jy = [rand() < 0.5 ? J : -J for i in 1:L, j in 1:L, k in 1:L]
        Jz = [rand() < 0.5 ? J : -J for i in 1:L, j in 1:L, k in 1:L]
    else
        error("Unknown distribution: $dist. Use :gaussian or :uniform")
    end
    return Jx, Jy, Jz
end

function metropolis_update!(config, beta, L, Jx, Jy, Jz)
    inds_x = shuffle(1:L)
    inds_y = shuffle(1:L)
    inds_z = shuffle(1:L)
    for i in inds_x
        for j in inds_y
            for k in inds_z
                s = config[i, j, k]
                ip = mod1(i+1, L); im = mod1(i-1, L)
                jp = mod1(j+1, L); jm = mod1(j-1, L)
                kp = mod1(k+1, L); km = mod1(k-1, L)
                local_field = Jx[i,j,k] * (config[ip,j,k] + config[im,j,k]) +
                            Jy[i,j,k] * (config[i,jp,k] + config[i,jm,k]) +
                            Jz[i,j,k] * (config[i,j,kp] + config[i,j,km])
                delta_E = 2 * s * local_field
                if rand() < min(1.0, exp(-beta * delta_E))
                    config[i, j, k] = -s
                end
            end
        end
    end
    return config
end

function joint_metropolis_sampler(state, beta, L, Jx, Jy, Jz)
    sigma, tau = state
    metropolis_update!(sigma, beta, L, Jx, Jy, Jz)
    metropolis_update!(tau, beta, L, Jx, Jy, Jz)
    return (sigma, tau)
end

function calc_energy(config, L, Jx, Jy, Jz)
    energy = 0.0
    for i in 1:L
        for j in 1:L
            for k in 1:L
                ip = mod1(i+1, L)
                jp = mod1(j+1, L)
                kp = mod1(k+1, L)
                energy -= Jx[i,j,k] * config[i,j,k] * config[ip,j,k]
                energy -= Jy[i,j,k] * config[i,j,k] * config[i,jp,k]
                energy -= Jz[i,j,k] * config[i,j,k] * config[i,j,kp]
            end
        end
    end
    return energy
end

function calc_joint_energy(state, L, Jx, Jy, Jz)
    sigma, tau = state
    return calc_energy(sigma, L, Jx, Jy, Jz) + calc_energy(tau, L, Jx, Jy, Jz)
end

function calc_overlap(state, L)
    sigma, tau = state
    return sum(sigma .* tau) / (L^3)
end

function set_temperature_ladder(T_min, T_max; num_replicas=20, method=:geometric)
    if method == :geometric
        R = (T_max / T_min)^(1/(num_replicas - 1))
        T_replicas = [T_min * R^(r - 1) for r in 1:num_replicas]
    elseif method == :inverse_linear
        T_replicas = [1/(1/T_max + (1/T_min - 1/T_max) * (r - 1)/(num_replicas - 1)) for r in 1:num_replicas]
    else
        error("Unknown method for temperature ladder")
    end
    return T_replicas
end

function replica_exchange_event!(configs, betas, L, Jx, Jy, Jz, exchange_probs_sum, exchange_count)
    num_replicas = length(configs)
    for r in 1:(num_replicas - 1)
        E1 = calc_joint_energy(configs[r], L, Jx, Jy, Jz)
        E2 = calc_joint_energy(configs[r+1], L, Jx, Jy, Jz)
        delta_beta = betas[r+1] - betas[r]
        delta_E = E2 - E1
        exchange_prob = min(1.0, exp(delta_beta * delta_E))
        if rand() < exchange_prob
            configs[r], configs[r+1] = configs[r+1], configs[r]
        end
        exchange_probs_sum[r] += exchange_prob
    end
    exchange_count += 1
    return exchange_probs_sum, exchange_count
end

function ising_spin_glass_model(L, state, move, Jx, Jy, Jz; num_replicas=32, T_min=0.5, T_max=2.5, eqSteps=10^6, mcSteps=10^4)
    T_replicas = set_temperature_ladder(T_min, T_max; num_replicas=num_replicas)
    betas = 1.0 ./ T_replicas
    num_replicas = length(betas)
    
    configs = [deepcopy(state) for _ in 1:num_replicas]

    E_sum = zeros(num_replicas)
    E2_sum = zeros(num_replicas)
    q_sum = zeros(num_replicas)
    q2_sum = zeros(num_replicas)
    q4_sum = zeros(num_replicas)
    q_values = [Float64[] for _ in 1:num_replicas]

    exchange_probs_sum = zeros(num_replicas - 1)
    exchange_count = 0
    
    for step in 1:eqSteps
        for r in 1:num_replicas
            configs[r] = move(configs[r], betas[r], L, Jx, Jy, Jz)
        end
        if step % 5 == 0
            exchange_probs_sum, exchange_count = replica_exchange_event!(configs, betas, L, Jx, Jy, Jz, exchange_probs_sum, exchange_count)
        end
    end
    
    for step in 1:mcSteps
        for r in 1:num_replicas
            configs[r] = move(configs[r], betas[r], L, Jx, Jy, Jz)
        end
        for r in 1:num_replicas
            energy = calc_joint_energy(configs[r], L, Jx, Jy, Jz)
            E_sum[r] += energy
            E2_sum[r] += energy^2
              
            q_val = calc_overlap(configs[r], L)
            q_sum[r] += q_val
            q2_sum[r] += q_val^2
            q4_sum[r] += q_val^4
            push!(q_values[r], q_val)
        end
        if step % 5 == 0
            exchange_probs_sum, exchange_count = replica_exchange_event!(configs, betas, L, Jx, Jy, Jz, exchange_probs_sum, exchange_count)
        end
    end

    E = [E_sum[r] / mcSteps for r in 1:num_replicas]
    C = [(E2_sum[r] / mcSteps - E[r]^2) * betas[r]^2 for r in 1:num_replicas]
    q_avg = [q_sum[r] / mcSteps for r in 1:num_replicas]
    q2_avg = [q2_sum[r] / mcSteps for r in 1:num_replicas]
    q4_avg = [q4_sum[r] / mcSteps for r in 1:num_replicas]
    Binder = [1 - q4_avg[r] / (3 * (q2_avg[r])^2) for r in 1:num_replicas]
    χ_SG = [(L^3) * (q2_avg[r] - (q_avg[r])^2) for r in 1:num_replicas]
    exchange_prob_means = exchange_probs_sum ./ exchange_count
    
    return T_replicas, E, C, q_avg, Binder, χ_SG, q_values, exchange_prob_means
end

export initial_state, initial_couplings, joint_metropolis_sampler, calc_energy, calc_joint_energy, calc_overlap, set_temperature_ladder, replica_exchange_event!, ising_spin_glass_model

end