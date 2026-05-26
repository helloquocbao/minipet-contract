#[test_only]
module pet_nft::pet_nft_tests {
    use std::string;
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::random::{Self, Random};
    
    use pet_token::pet_token::{Self, PET_TOKEN};
    use pet_nft::pet_nft::{Self, AdminCap, GlobalConfig, MintSlot, PetTemplate, PetNFT};

    const ADMIN: address = @0xAD;
    const USER: address = @0x123;
    const TREASURY: address = @0x999;

    fun setup_test(): (Scenario, Clock) {
        let mut scenario = test_scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000); // T=1000
        
        // Init pet token
        pet_token::test_init(test_scenario::ctx(&mut scenario));
        // Init pet nft
        pet_nft::test_init(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, @0x0);
        random::create_for_testing(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            // Set treasury to TREASURY
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            pet_nft::update_treasury(&admin_cap, &mut config, TREASURY);
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        (scenario, clock)
    }

    #[test]
    fun test_admin_functions() {
        let (mut scenario, clock) = setup_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            
            pet_nft::update_config(&admin_cap, &mut config, 5000);
            pet_nft::increase_mint_limit(&admin_cap, &mut config, 5);
            
            pet_nft::create_template(
                &admin_cap,
                &mut config,
                b"Test Pet",
                b"img",
                sui::object::id_from_address(@0x1),
                b"sprite",
                sui::object::id_from_address(@0x2),
                1000,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_custom() {
        let (mut scenario, clock) = setup_test();
        
        // Mint some PET_TOKEN for user
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut treasury = test_scenario::take_from_sender<TreasuryCap<PET_TOKEN>>(&scenario);
            pet_token::mint(&mut treasury, 20000 * 1000000000, USER, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_sender(&scenario, treasury);
        };
        
        // Buy slot
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut payment = test_scenario::take_from_sender<Coin<PET_TOKEN>>(&scenario);
            
            pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, payment);
        };
        
        // Mint custom pet
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let slot = test_scenario::take_from_sender<MintSlot>(&scenario);
            let mut random = test_scenario::take_shared<Random>(&scenario);
            
            test_scenario::next_tx(&mut scenario, @0x0);
            random::update_randomness_state_for_testing(
                &mut random,
                0,
                x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
                test_scenario::ctx(&mut scenario),
            );
            
            test_scenario::next_tx(&mut scenario, USER);
            
            pet_nft::mint_custom_with_slot(
                &mut config,
                slot,
                b"My Custom Pet",
                b"url",
                sui::object::id_from_address(@0x1),
                b"sprite",
                sui::object::id_from_address(@0x2),
                b"custom",
                &clock,
                &random,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(random);
            test_scenario::return_shared(config);
        };
        
        // Verify pet
        test_scenario::next_tx(&mut scenario, USER);
        {
            let pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            assert!(pet_nft::level(&pet) == 1, 0);
            assert!(pet_nft::born_at(&pet) == 1000, 0);
            pet_nft::burn(pet); // test burn
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_buy_pet_from_store() {
        let (mut scenario, clock) = setup_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            pet_nft::create_template(&admin_cap, &mut config, b"Store Pet", b"img", sui::object::id_from_address(@0x1), b"sprite", sui::object::id_from_address(@0x2), 100, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let mut random = test_scenario::take_shared<Random>(&scenario);
            
            test_scenario::next_tx(&mut scenario, @0x0);
            random::update_randomness_state_for_testing(
                &mut random,
                0,
                x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
                test_scenario::ctx(&mut scenario),
            );
            
            test_scenario::next_tx(&mut scenario, USER);
            
            let payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            
            pet_nft::buy_pet(&config, &template, payment, &clock, &random, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared(random);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            assert!(pet_nft::level(&pet) == 1, 0);
            test_scenario::return_to_sender(&scenario, pet);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_pet_actions() {
        let (mut scenario, clock) = setup_test();
        
        // Setup Pet
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            pet_nft::create_template(&admin_cap, &mut config, b"Store Pet", b"img", sui::object::id_from_address(@0x1), b"sprite", sui::object::id_from_address(@0x2), 100, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let mut random = test_scenario::take_shared<Random>(&scenario);
            test_scenario::next_tx(&mut scenario, @0x0);
            random::update_randomness_state_for_testing(&mut random, 0, x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F", test_scenario::ctx(&mut scenario));
            
            test_scenario::next_tx(&mut scenario, USER);
            let payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, payment, &clock, &random, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(random);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };
        
        // Test send_message
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            
            // Send 1 SUI -> 10^9 MIST = 100 EXP -> Level up to 2
            let mut payment = coin::mint_for_testing<SUI>(1000000000, test_scenario::ctx(&mut scenario));
            
            pet_nft::send_message(&config, &mut pet, &mut payment, @0x456, b"Hello", test_scenario::ctx(&mut scenario));
            
            assert!(pet_nft::level(&pet) == 2, 0); // 100 EXP = 1 level up
            
            test_scenario::return_to_sender(&scenario, pet);
            
            // Clean up remaining payment (should be empty since it sends all except 1% fee)
            // Wait, we split 1% to fee, and then we sent the rest to recipient. The remaining payment object should be empty.
            coin::burn_for_testing(payment);
            test_scenario::return_shared(config);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}
