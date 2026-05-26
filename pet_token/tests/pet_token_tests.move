#[test_only]
module pet_token::pet_token_tests {
    use sui::test_scenario;
    use sui::coin::{Self, Coin, TreasuryCap};
    use pet_token::pet_token::{Self, PET_TOKEN};

    #[test]
    fun test_init_and_mint() {
        let admin = @0xAD;
        let user = @0x123;
        
        let mut scenario = test_scenario::begin(admin);
        
        // 1. Init
        pet_token::test_init(test_scenario::ctx(&mut scenario));
        
        // 2. Mint
        test_scenario::next_tx(&mut scenario, admin);
        {
            let mut treasury = test_scenario::take_from_sender<TreasuryCap<PET_TOKEN>>(&scenario);
            pet_token::mint(&mut treasury, 1000, user, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_sender(&scenario, treasury);
        };
        
        // 3. Verify and Burn
        test_scenario::next_tx(&mut scenario, user);
        {
            let mut coin = test_scenario::take_from_sender<Coin<PET_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 1000, 0);
            
            test_scenario::next_tx(&mut scenario, admin);
            let mut treasury = test_scenario::take_from_sender<TreasuryCap<PET_TOKEN>>(&scenario);
            pet_token::burn(&mut treasury, coin);
            test_scenario::return_to_sender(&scenario, treasury);
        };
        
        test_scenario::end(scenario);
    }
}
