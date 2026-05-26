#[test_only]
#[allow(lint(public_random))]
module pet_nft::security_tests {
    use sui::test_scenario;
    use sui::clock;
    use sui::coin;
    use sui::random;
    use sui::sui::SUI;
    use sui::test_utils;
    use pet_nft::pet_nft::{Self, GlobalConfig, AdminCap, PetNFT, PetTemplate};
    use pet_token::pet_token::{Self, PET_TOKEN};

    #[test]
    fun test_treasury_and_fees() {
        let admin = @0xAD;
        let treasury = @0xBC;
        let user = @0x123;
        
        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        
        // 1. Setup
        test_scenario::next_tx(scenario, admin);
        {
            pet_nft::test_init(test_scenario::ctx(scenario));
            pet_token::test_init(test_scenario::ctx(scenario));
        };
        
        // 2. Admin sets treasury
        test_scenario::next_tx(scenario, admin);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            
            pet_nft::update_treasury(&admin_cap, &mut config, treasury);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(config);
        };
        
        // 3. User buys mint slot
        test_scenario::next_tx(scenario, user);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(10000 * 1000000000, test_scenario::ctx(scenario));
            
            pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(scenario));
            
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };
        
        // 4. Verify treasury received funds
        test_scenario::next_tx(scenario, treasury);
        {
            let fee_coin = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(scenario);
            assert!(coin::value(&fee_coin) == 10000 * 1000000000, 0);
            test_scenario::return_to_sender(scenario, fee_coin);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_secure_minting() {
        let admin = @0xAD;
        let user = @0x123;
        
        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        
        // 1. Setup
        test_scenario::next_tx(scenario, admin);
        {
            pet_nft::test_init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, @0x0);
        {
            random::create_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, @0x0);
        {
            let mut random_state = test_scenario::take_shared<random::Random>(scenario);
            random::update_randomness_state_for_testing(
                &mut random_state,
                0,
                x"0102030405060708091011121314151617181920212223242526272829303132",
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(random_state);
        };
        
        // 2. Create template
        test_scenario::next_tx(scenario, admin);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let dummy_id = sui::object::id(&admin_cap);
            pet_nft::create_template(
                &admin_cap,
                &mut config,
                b"TestPet",
                b"img",
                dummy_id,
                b"sprite",
                dummy_id,
                1000,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(config);
        };
        
        // 3. User buys pet
        test_scenario::next_tx(scenario, user);
        {
            let config = test_scenario::take_shared<GlobalConfig>(scenario);
            let template = test_scenario::take_shared<PetTemplate>(scenario);
            let random_state = test_scenario::take_shared<random::Random>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let payment = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
            
            pet_nft::buy_pet(
                &config,
                &template,
                payment,
                &clock,
                &random_state,
                test_scenario::ctx(scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(config);
            test_scenario::return_shared(template);
            test_scenario::return_shared(random_state);
        };
        
        // 4. Verify pet and perfection score
        test_scenario::next_tx(scenario, user);
        {
            let pet = test_scenario::take_from_sender<PetNFT>(scenario);
            assert!(pet_nft::perfection_score(&pet) > 0, 1);
            test_scenario::return_to_sender(scenario, pet);
        };
        
        test_scenario::end(scenario_val);
    }
}
