#[test_only]
#[allow(deprecated_usage)]
module pet_nft::pet_nft_tests {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use sui::clock;
    use sui::random;
    use sui::test_utils;
    use pet_token::pet_token::{Self, PET_TOKEN};
    use pet_nft::pet_nft::{Self, AdminCap, GlobalConfig, MintSlot, PetTemplate, PetNFT};

    const ADMIN: address = @0xAD;
    const USER: address = @0x123;
    const TREASURY: address = @0x999;

    fun setup(): (sui::test_scenario::Scenario, clock::Clock) {
        let mut scenario = test_scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        pet_token::test_init(test_scenario::ctx(&mut scenario));
        pet_nft::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        random::create_for_testing(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut r = test_scenario::take_shared<random::Random>(&scenario);
            random::update_randomness_state_for_testing(&mut r, 0, x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(r);
        };

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

    fun create_test_template(scenario: &mut sui::test_scenario::Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(scenario);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"TestPet", b"balanced", b"A test pet",
                b"img", dummy_id,
                b"sprite_normal", dummy_id,
                b"sprite_rare", dummy_id,
                b"sprite_sr", dummy_id,
                b"sprite_legend", dummy_id,
                100u64,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(scenario, admin_cap);
        };
    }

    #[test]
    fun test_admin_update_config() {
        let (mut scenario, clock) = setup();
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            pet_nft::update_config(&admin_cap, &mut config, 5000);
            pet_nft::increase_mint_limit(&admin_cap, &mut config, 10);
            pet_nft::update_rename_fee(&admin_cap, &mut config, 100 * 1000000000);
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_buy_mint_slot_and_mint_custom() {
        let (mut scenario, clock) = setup();

        // Give user MIPET tokens (from admin's 250M)
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut admin_coins = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            let user_coin = coin::split(&mut admin_coins, 20000 * 1000000000, test_scenario::ctx(&mut scenario));
            sui::transfer::public_transfer(user_coin, USER);
            test_scenario::return_to_sender(&scenario, admin_coins);
        };

        // User buys slot
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut payment = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, payment);
        };

        // User mints custom pet
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let slot = test_scenario::take_from_sender<MintSlot>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            pet_nft::mint_custom_with_slot(
                &mut config, slot,
                b"MyPet", b"img_url", sui::object::id_from_address(@0x1),
                b"sprite_url", sui::object::id_from_address(@0x2),
                b"custom-slug", &clock, &random_state,
                test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(config);
        };

        // Verify pet created
        test_scenario::next_tx(&mut scenario, USER);
        {
            let pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            assert!(pet_nft::level(&pet) == 1, 0);
            assert!(pet_nft::born_at(&pet) == 1000, 0);
            assert!(pet_nft::perfection_score(&pet) > 0, 0);
            pet_nft::burn(pet);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_buy_pet_from_store() {
        let (mut scenario, clock) = setup();
        create_test_template(&mut scenario);

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(500, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            assert!(coin::value(&payment) == 400, 0); // 500 - 100 price
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
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
    fun test_send_message_leveling() {
        let (mut scenario, clock) = setup();
        create_test_template(&mut scenario);

        // Buy pet for USER
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };

        // Send message with 1 SUI (= 100 EXP = level up)
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(5_000_000_000, test_scenario::ctx(&mut scenario));
            pet_nft::send_message(&config, &mut pet, &mut payment, 1_000_000_000, @0x456, b"Hello", test_scenario::ctx(&mut scenario));
            assert!(coin::value(&payment) == 4_000_000_000, 0);
            assert!(pet_nft::level(&pet) == 2, 0);
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_bonk_pet() {
        let (mut scenario, clock) = setup();
        create_test_template(&mut scenario);

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(200 * 1000000000, test_scenario::ctx(&mut scenario));
            pet_nft::bonk_pet(&config, &mut pet, &mut payment, @0x789, test_scenario::ctx(&mut scenario));
            assert!(coin::value(&payment) == 100 * 1000000000, 0);
            assert!(pet_nft::experience(&pet) == 50, 0);
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_rename_pet() {
        let (mut scenario, clock) = setup();
        create_test_template(&mut scenario);

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(100 * 1000000000, test_scenario::ctx(&mut scenario));
            pet_nft::rename_pet(&config, &mut pet, &mut payment, b"NewName", test_scenario::ctx(&mut scenario));
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_buy_slot_insufficient_funds() {
        let (mut scenario, clock) = setup();
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(100 * 1000000000, test_scenario::ctx(&mut scenario)); // only 100, need 10000
            pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_bonk_insufficient_funds() {
        let (mut scenario, clock) = setup();
        create_test_template(&mut scenario);

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(50 * 1000000000, test_scenario::ctx(&mut scenario)); // 50 < 100 required
            pet_nft::bonk_pet(&config, &mut pet, &mut payment, @0x789, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_mint_limit_reached() {
        let (mut scenario, clock) = setup();

        // Set mint limit to 0
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            // Default limit is 10, set count = limit to trigger
            pet_nft::update_config(&admin_cap, &mut config, 0);
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };

        // Give user tokens and buy slot
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut admin_coins = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            let user_coin = coin::split(&mut admin_coins, 20000 * 1000000000, test_scenario::ctx(&mut scenario));
            sui::transfer::public_transfer(user_coin, USER);
            test_scenario::return_to_sender(&scenario, admin_coins);
        };

        // Fill up the mint limit (mint 10 pets to reach limit)
        let mut i = 0;
        while (i < 10) {
            test_scenario::next_tx(&mut scenario, USER);
            {
                let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
                let mut payment = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
                pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(&mut scenario));
                test_scenario::return_shared(config);
                test_scenario::return_to_sender(&scenario, payment);
            };
            test_scenario::next_tx(&mut scenario, USER);
            {
                let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
                let slot = test_scenario::take_from_sender<MintSlot>(&scenario);
                let random_state = test_scenario::take_shared<random::Random>(&scenario);
                pet_nft::mint_custom_with_slot(
                    &mut config, slot,
                    b"Pet", b"img", sui::object::id_from_address(@0x1),
                    b"sprite", sui::object::id_from_address(@0x2),
                    b"slug", &clock, &random_state,
                    test_scenario::ctx(&mut scenario)
                );
                test_scenario::return_shared(random_state);
                test_scenario::return_shared(config);
            };
            i = i + 1;
        };

        // 11th mint should fail
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut payment = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, payment);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let slot = test_scenario::take_from_sender<MintSlot>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            pet_nft::mint_custom_with_slot(
                &mut config, slot,
                b"Pet", b"img", sui::object::id_from_address(@0x1),
                b"sprite", sui::object::id_from_address(@0x2),
                b"slug", &clock, &random_state,
                test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(config);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}
