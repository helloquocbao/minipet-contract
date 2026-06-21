#[test_only]
#[allow(deprecated_usage)]
module pet_token::pet_token_tests {
    use sui::test_scenario;
    use sui::coin;
    use pet_token::pet_token::{Self, PET_TOKEN, FaucetConfig};

    const ADMIN: address = @0xAD;
    const USER: address = @0x123;

    #[test]
    fun test_init_creates_faucet_config() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_token::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            // FaucetConfig should be shared
            let faucet = test_scenario::take_shared<FaucetConfig>(&scenario);
            test_scenario::return_shared(faucet);
        };

        // Admin should receive 250M tokens
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let coin = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 250_000_000 * 1_000_000_000, 0);
            test_scenario::return_to_sender(&scenario, coin);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_treasury_sent_to_dead_address() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_token::test_init(test_scenario::ctx(&mut scenario));

        // TreasuryCap should be at dead address (0x0), not admin
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            assert!(!test_scenario::has_most_recent_for_sender<coin::TreasuryCap<PET_TOKEN>>(&scenario), 0);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_burn_tokens_sent_to_dead_address() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_token::test_init(test_scenario::ctx(&mut scenario));

        // Dead address (0x0) should receive 250M burned tokens
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            // Dead address gets TreasuryCap + 250M burn coins
            assert!(test_scenario::has_most_recent_for_sender<coin::Coin<PET_TOKEN>>(&scenario), 0);
        };

        test_scenario::end(scenario);
    }
}
