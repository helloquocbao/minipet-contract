#[test_only]
module pet_nft::pet_nft_tests {
    use sui::test_scenario;
    use sui::clock::{Self, Clock};
    use pet_nft::pet_nft::{Self, PetNFT, AdminCap};

    #[test]
    fun test_mint_pet() {
        let admin = @0x1;
        let user = @0x2;
        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        
        // 1. Init
        test_scenario::next_tx(scenario, admin);
        {
            pet_nft::test_init(test_scenario::ctx(scenario));
        };
        
        // 2. Mint pet
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::set_for_testing(&mut clock, 1000);
            
            pet_nft::mint_pet(
                &admin_cap,
                b"MiniCat",
                b"https://example.com/cat.png",
                b"cat",
                &clock,
                user,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };
        
        // 3. Verify pet created
        test_scenario::next_tx(scenario, user);
        {
            let mut pet = test_scenario::take_from_sender<PetNFT>(scenario);
            
            // Tăng level
            pet_nft::level_up(&mut pet);
            
            // Update happiness
            pet_nft::update_happiness(&mut pet, 50);
            
            // Record focus session
            pet_nft::record_focus_session(&mut pet);
            
            test_scenario::return_to_sender(scenario, pet);
        };
        
        test_scenario::end(scenario_val);
    }
}
