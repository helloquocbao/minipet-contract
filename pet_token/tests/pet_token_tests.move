#[test_only]
module pet_token::pet_token_tests {
    use sui::test_scenario;
    use sui::coin::{Self, TreasuryCap};
    use pet_token::pet_token::{Self, PET_TOKEN, FaucetConfig};

    const ADMIN: address = @0xAD;
    const USER: address = @0x123;

    #[test]
    fun test_mint_and_burn() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_token::test_init(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut treasury = test_scenario::take_from_sender<TreasuryCap<PET_TOKEN>>(&scenario);
            pet_token::mint(&mut treasury, 1000 * 1000000000, USER, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_sender(&scenario, treasury);
        };
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 1000 * 1000000000, 0);
            
            // Test burn
            test_scenario::next_tx(&mut scenario, ADMIN);
            let mut treasury = test_scenario::take_from_address<TreasuryCap<PET_TOKEN>>(&scenario, ADMIN);
            pet_token::burn(&mut treasury, coin);
            test_scenario::return_to_address(ADMIN, treasury);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_token_faucet() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_token::test_init(test_scenario::ctx(&mut scenario));
        
        // User claims token from faucet
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut treasury = test_scenario::take_from_address<TreasuryCap<PET_TOKEN>>(&scenario, ADMIN);
            let faucet = test_scenario::take_shared<FaucetConfig>(&scenario);
            
            pet_token::claim_token(&mut treasury, &faucet, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared(faucet);
            test_scenario::return_to_address(ADMIN, treasury);
        };
        
        // Verify user received 10001 MIPET
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 10001 * 1000000000, 0);
            test_scenario::return_to_sender(&scenario, coin);
        };
        
        test_scenario::end(scenario);
    }
}
