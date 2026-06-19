#[test_only]
module pet_nft::pet_nft_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::random::{Self, Random};
    use sui::test_utils;
    
    use pet_token::pet_token::{Self, PET_TOKEN};
    use pet_nft::pet_nft::{Self, AdminCap, GlobalConfig, MintSlot, PetTemplate, PetNFT};

    const ADMIN: address = @0xAD;
    const USER: address = @0x123;
    const TREASURY: address = @0x999;

    fun setup_test(): (Scenario, Clock) {
        let mut scenario = test_scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        pet_token::test_init(test_scenario::ctx(&mut scenario));
        pet_nft::test_init(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, @0x0);
        random::create_for_testing(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
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
            
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Test Pet", b"img", dummy_id,
                b"sprite_normal", dummy_id,
                b"sprite_rare", dummy_id,
                b"sprite_sr", dummy_id,
                b"sprite_legend", dummy_id,
                1000u64,
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
        
        // Mint PET_TOKEN for user
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
        
        // Setup random
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut random = test_scenario::take_shared<Random>(&scenario);
            random::update_randomness_state_for_testing(
                &mut random, 0,
                x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(random);
        };
        
        // Mint custom pet
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let slot = test_scenario::take_from_sender<MintSlot>(&scenario);
            let random = test_scenario::take_shared<Random>(&scenario);
            
            pet_nft::mint_custom_with_slot(
                &mut config, slot,
                b"My Custom Pet", b"url", sui::object::id_from_address(@0x1),
                b"sprite", sui::object::id_from_address(@0x2),
                b"custom", &clock, &random,
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
            pet_nft::burn(pet);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_buy_pet_from_store() {
        let (mut scenario, clock) = setup_test();
        
        // Create template
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Store Pet", b"img", dummy_id,
                b"sprite_normal", dummy_id,
                b"sprite_rare", dummy_id,
                b"sprite_sr", dummy_id,
                b"sprite_legend", dummy_id,
                100u64,
                test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        // Setup random
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut random = test_scenario::take_shared<Random>(&scenario);
            random::update_randomness_state_for_testing(
                &mut random, 0,
                x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(random);
        };
        
        // Buy pet with overpayment (test refund)
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random = test_scenario::take_shared<Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(500, test_scenario::ctx(&mut scenario));
            
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random, test_scenario::ctx(&mut scenario));
            
            // Verify refund: paid 500, price 100 -> remaining 400
            assert!(coin::value(&payment) == 400, 0);
            
            test_utils::destroy(payment);
            test_scenario::return_shared(random);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };
        
        // Verify pet
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
    fun test_send_message_with_amount() {
        let (mut scenario, clock) = setup_test();
        
        // Create template + buy pet
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Pet", b"img", dummy_id,
                b"sn", dummy_id, b"sr", dummy_id, b"ssr", dummy_id, b"sl", dummy_id,
                100u64, test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut random = test_scenario::take_shared<Random>(&scenario);
            random::update_randomness_state_for_testing(&mut random, 0, x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(random);
        };
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random = test_scenario::take_shared<Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };
        
        // Test send_message with specific amount (not drain all)
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(5_000_000_000, test_scenario::ctx(&mut scenario)); // 5 SUI
            
            // Send only 1 SUI from 5 SUI coin
            pet_nft::send_message(&config, &mut pet, &mut payment, 1_000_000_000, @0x456, b"Hello", test_scenario::ctx(&mut scenario));
            
            // Remaining should be 4 SUI
            assert!(coin::value(&payment) == 4_000_000_000, 0);
            // Level should increase (1 SUI = 100 EXP = 1 level up)
            assert!(pet_nft::level(&pet) == 2, 0);
            
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_bonk_pet_with_balance_check() {
        let (mut scenario, clock) = setup_test();
        
        // Create template + buy pet
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Pet", b"img", dummy_id,
                b"sn", dummy_id, b"sr", dummy_id, b"ssr", dummy_id, b"sl", dummy_id,
                100u64, test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut random = test_scenario::take_shared<Random>(&scenario);
            random::update_randomness_state_for_testing(&mut random, 0, x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(random);
        };
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random = test_scenario::take_shared<Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };
        
        // Test bonk with sufficient balance
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(200 * 1000000000, test_scenario::ctx(&mut scenario));
            
            pet_nft::bonk_pet(&config, &mut pet, &mut payment, @0x789, test_scenario::ctx(&mut scenario));
            
            // Remaining: 200 - 100 = 100 MIPET
            assert!(coin::value(&payment) == 100 * 1000000000, 0);
            // EXP gained: 50
            assert!(pet_nft::experience(&pet) == 50, 0);
            
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_bonk_insufficient_funds() {
        let (mut scenario, clock) = setup_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Pet", b"img", dummy_id,
                b"sn", dummy_id, b"sr", dummy_id, b"ssr", dummy_id, b"sl", dummy_id,
                100u64, test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut random = test_scenario::take_shared<Random>(&scenario);
            random::update_randomness_state_for_testing(&mut random, 0, x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(random);
        };
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random = test_scenario::take_shared<Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };
        
        // Bonk with insufficient balance (50 MIPET < 100 required)
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(50 * 1000000000, test_scenario::ctx(&mut scenario));
            
            pet_nft::bonk_pet(&config, &mut pet, &mut payment, @0x789, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}
