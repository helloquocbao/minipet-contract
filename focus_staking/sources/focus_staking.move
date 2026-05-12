module focus_staking::focus_staking {
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use pet_token::pet_token::PET_TOKEN;

    const EInvalidDuration: u64 = 1;
    const ELockNotExpired: u64 = 2;

    public struct StakePool has key {
        id: UID,
        total_staked: Balance<SUI>,
        reward_reserve: Balance<PET_TOKEN>,
    }

    public struct StakePosition has key, store {
        id: UID,
        owner: address,
        principal: Balance<SUI>,
        lock_duration_ms: u64,
        start_time_ms: u64,
        last_claimed_ms: u64,
        apy_bps: u64,
    }

    fun init(ctx: &mut TxContext) {
        let pool = StakePool {
            id: object::new(ctx),
            total_staked: balance::zero(),
            reward_reserve: balance::zero(),
        };
        transfer::share_object(pool);
    }

    public fun deposit_reward_reserve(pool: &mut StakePool, reward: Coin<PET_TOKEN>) {
        balance::join(&mut pool.reward_reserve, coin::into_balance(reward));
    }

    public fun stake(
        pool: &mut StakePool,
        payment: Coin<SUI>,
        duration_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let mut apy_bps = 0;
        if (duration_ms == 604800000) {
            apy_bps = 500;
        } else if (duration_ms == 2592000000) {
            apy_bps = 1200;
        } else if (duration_ms == 7776000000) {
            apy_bps = 2500;
        } else {
            assert!(false, EInvalidDuration);
        };

        let principal_balance = coin::into_balance(payment);
        let principal_val = balance::value(&principal_balance);
        
        // Increase total_staked tracking in pool
        // balance::join(&mut pool.total_staked, principal_balance); 
        // We can't join it to the pool if we are keeping it in the position. So we just keep it in position.
        
        let current_time = clock::timestamp_ms(clock);

        let position = StakePosition {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            principal: principal_balance,
            lock_duration_ms: duration_ms,
            start_time_ms: current_time,
            last_claimed_ms: current_time,
            apy_bps,
        };
        
        transfer::public_transfer(position, tx_context::sender(ctx));
    }

    public fun claim_rewards(
        pool: &mut StakePool,
        position: &mut StakePosition,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        let elapsed_ms = current_time - position.last_claimed_ms;
        
        let principal_val = balance::value(&position.principal);
        // daily_reward = (principal * apy_bps) / (10000 * 365)
        // reward = daily_reward * (elapsed_ms / 86400000)
        let elapsed_days = elapsed_ms / 86400000;
        let reward_val = (principal_val * position.apy_bps * elapsed_days) / 3650000;
        
        if (reward_val > 0) {
            let reward_coin = coin::take(&mut pool.reward_reserve, reward_val, ctx);
            transfer::public_transfer(reward_coin, tx_context::sender(ctx));
            position.last_claimed_ms = position.last_claimed_ms + (elapsed_days * 86400000);
        }
    }

    public fun unstake(
        pool: &mut StakePool,
        position: StakePosition,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= position.start_time_ms + position.lock_duration_ms, ELockNotExpired);

        // Claim remaining rewards
        let mut mut_pos = position;
        claim_rewards(pool, &mut mut_pos, clock, ctx);

        let StakePosition {
            id,
            owner: _,
            principal,
            lock_duration_ms: _,
            start_time_ms: _,
            last_claimed_ms: _,
            apy_bps: _,
        } = mut_pos;

        let principal_coin = coin::from_balance(principal, ctx);
        transfer::public_transfer(principal_coin, tx_context::sender(ctx));
        object::delete(id);
    }

    public fun emergency_unstake(
        position: StakePosition,
        ctx: &mut TxContext
    ) {
        // No rewards
        let StakePosition {
            id,
            owner: _,
            principal,
            lock_duration_ms: _,
            start_time_ms: _,
            last_claimed_ms: _,
            apy_bps: _,
        } = position;

        let principal_coin = coin::from_balance(principal, ctx);
        transfer::public_transfer(principal_coin, tx_context::sender(ctx));
        object::delete(id);
    }
}
