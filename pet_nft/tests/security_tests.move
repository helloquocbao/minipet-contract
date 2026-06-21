#[test_only]
#[allow(lint(public_random), deprecated_usage)]
module pet_nft::security_tests {
    use sui::test_scenario;
    use sui::clock;
    use sui::coin;
    use sui::random;
    use sui::sui::SUI;
    use sui::test_utils;
    use pet_nft::pet_nft::{Self, GlobalConfig, AdminCap, PetNFT, PetTemplate};
    use pet_token::pet_token::{Self, PET_TOKEN};

    const ADMIN: address = @0xAD;
    const TREASURY: address = @0xBC;
    const USER: address = @0x123;

    #[test]
    fun test_treasury_receives_fees() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_nft::test_init(test_scenario::ctx(&mut scenario));
        pet_token::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            pet_nft::update_treasury(&admin_cap, &mut config, TREASURY);
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(config);
        };

        // User buys mint slot
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut payment = coin::mint_for_testing<PET_TOKEN>(10000 * 1000000000, test_scenario::ctx(&mut scenario));
            pet_nft::buy_mint_slot(&mut config, &mut payment, test_scenario::ctx(&mut scenario));
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };

        // Verify treasury received the fee
        test_scenario::next_tx(&mut scenario, TREASURY);
        {
            let fee_coin = test_scenario::take_from_sender<coin::Coin<PET_TOKEN>>(&scenario);
            assert!(coin::value(&fee_coin) == 10000 * 1000000000, 0);
            test_scenario::return_to_sender(&scenario, fee_coin);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_buy_pet_payment_goes_to_treasury() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_nft::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        random::create_for_testing(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut r = test_scenario::take_shared<random::Random>(&scenario);
            random::update_randomness_state_for_testing(&mut r, 0, x"0102030405060708091011121314151617181920212223242526272829303132", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(r);
        };

        // Set treasury
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            pet_nft::update_treasury(&admin_cap, &mut config, TREASURY);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"TestPet", b"aggressive", b"A fierce pet",
                b"img", dummy_id,
                b"sprite_normal", dummy_id,
                b"sprite_rare", dummy_id,
                b"sprite_sr", dummy_id,
                b"sprite_legend", dummy_id,
                1000u64,
                test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(config);
        };

        // User buys pet
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let mut payment = coin::mint_for_testing<SUI>(5000, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            // Verify refund
            assert!(coin::value(&payment) == 4000, 0);
            clock::destroy_for_testing(clock);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
            test_scenario::return_shared(template);
            test_scenario::return_shared(random_state);
        };

        // Verify treasury received payment
        test_scenario::next_tx(&mut scenario, TREASURY);
        {
            let fee_coin = test_scenario::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&fee_coin) == 1000, 0);
            test_scenario::return_to_sender(&scenario, fee_coin);
        };

        // Verify pet created with valid perfection score
        test_scenario::next_tx(&mut scenario, USER);
        {
            let pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            assert!(pet_nft::perfection_score(&pet) > 0, 0);
            assert!(pet_nft::perfection_score(&pet) <= 100000, 0);
            test_scenario::return_to_sender(&scenario, pet);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_send_message_fee_split() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_nft::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        random::create_for_testing(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut r = test_scenario::take_shared<random::Random>(&scenario);
            random::update_randomness_state_for_testing(&mut r, 0, x"0102030405060708091011121314151617181920212223242526272829303132", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(r);
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            pet_nft::update_treasury(&admin_cap, &mut config, TREASURY);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Pet", b"balanced", b"desc",
                b"img", dummy_id,
                b"sn", dummy_id, b"sr", dummy_id, b"ssr", dummy_id, b"sl", dummy_id,
                100u64, test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let mut payment = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            clock::destroy_for_testing(clock);
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };

        // Send 1 SUI message: 1% fee to treasury, 99% to recipient
        let recipient = @0x456;
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let mut pet = test_scenario::take_from_sender<PetNFT>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(2_000_000_000, test_scenario::ctx(&mut scenario));
            pet_nft::send_message(&config, &mut pet, &mut payment, 1_000_000_000, recipient, b"Hi", test_scenario::ctx(&mut scenario));
            // 1% = 10_000_000 to treasury, 990_000_000 to recipient
            assert!(coin::value(&payment) == 1_000_000_000, 0); // remaining
            test_scenario::return_to_sender(&scenario, pet);
            test_utils::destroy(payment);
            test_scenario::return_shared(config);
        };

        // Verify treasury got 1% fee
        test_scenario::next_tx(&mut scenario, TREASURY);
        {
            let fee_coin = test_scenario::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&fee_coin) == 10_000_000, 0);
            test_scenario::return_to_sender(&scenario, fee_coin);
        };

        // Verify recipient got 99%
        test_scenario::next_tx(&mut scenario, recipient);
        {
            let recv_coin = test_scenario::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&recv_coin) == 990_000_000, 0);
            test_scenario::return_to_sender(&scenario, recv_coin);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_buy_pet_insufficient_funds() {
        let mut scenario = test_scenario::begin(ADMIN);
        pet_nft::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        random::create_for_testing(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, @0x0);
        {
            let mut r = test_scenario::take_shared<random::Random>(&scenario);
            random::update_randomness_state_for_testing(&mut r, 0, x"0102030405060708091011121314151617181920212223242526272829303132", test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(r);
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let dummy_id = sui::object::id_from_address(@0x1);
            pet_nft::create_template(
                &admin_cap, &mut config,
                b"Pet", b"balanced", b"desc",
                b"img", dummy_id,
                b"sn", dummy_id, b"sr", dummy_id, b"ssr", dummy_id, b"sl", dummy_id,
                1000u64, test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(config);
        };

        // Try buy with only 500 (need 1000)
        test_scenario::next_tx(&mut scenario, USER);
        {
            let config = test_scenario::take_shared<GlobalConfig>(&scenario);
            let template = test_scenario::take_shared<PetTemplate>(&scenario);
            let random_state = test_scenario::take_shared<random::Random>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let mut payment = coin::mint_for_testing<SUI>(500, test_scenario::ctx(&mut scenario));
            pet_nft::buy_pet(&config, &template, &mut payment, &clock, &random_state, test_scenario::ctx(&mut scenario));
            clock::destroy_for_testing(clock);
            test_utils::destroy(payment);
            test_scenario::return_shared(random_state);
            test_scenario::return_shared(template);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }
}
