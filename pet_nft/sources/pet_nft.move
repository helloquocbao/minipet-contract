#[allow(lint(public_entry), duplicate_alias, unused_use, unused_const, unused_field, lint(public_random), deprecated_usage)]
module pet_nft::pet_nft {
    use std::string::{Self, String};
    use std::vector;
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::display;
    use sui::package;
    use sui::hash;
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use pet_token::pet_token::PET_TOKEN;

    use sui::random::{Self, Random};

    /// Admin cap để mint (chỉ app mới có thể mint)
    public struct AdminCap has key { id: UID }

    /// Cấu hình toàn cục để quản lý giới hạn
    public struct GlobalConfig has key {
        id: UID,
        custom_mint_limit: u64,
        custom_mint_count: u64,
        base_slot_fee: u64,     // Phí cố định cho 1 slot
        treasury_address: address, // Địa chỉ nhận phí tập trung
        templates: vector<ID>, // Danh sách các ID của PetTemplate
    }

    /// Vật phẩm cho phép đúc Pet (Cần mua trước khi mint)
    public struct MintSlot has key, store {
        id: UID,
    }

    public struct PET_NFT has drop {}

    /// NFT chính
    public struct PetNFT has key, store {
        id: UID,
        name: String,
        image_url: String,   // Blob ID (Hash)
        image_blob_id: ID,   // Sui Object ID of the storage reservation
        sprite_url: String,  // Blob ID (Hash)
        sprite_blob_id: ID,  // Sui Object ID of the storage reservation
        slug: String,
        level: u64,
        experience: u64,
        happiness: u64,
        born_at: u64,
        perfection_score: u64,
        is_custom: bool,      
    }

    /// Template cho các loại Pet tiêu chuẩn (Cửa hàng)
    public struct PetTemplate has key, store {
        id: UID,
        name: String,
        image_url: String,
        image_blob_id: ID,
        sprite_url: String,
        sprite_blob_id: ID,
        price: u64,
    }

    /// Event
    public struct MessageEvent has copy, drop {
        sender: address, recipient: address, amount: u64,
        message: String, pet_slug: String, pet_image: String,
    }
    public struct GiftEvent has copy, drop {
        sender: address, recipient: address, amount: u64,
        message: String, pet_slug: String, pet_image: String,
    }
    public struct BonkEvent has copy, drop {
        bonker: address, target: address, fee: u64,
        pet_slug: String, pet_image: String,
    }

    /// Error codes
    const ENotOwner: u64 = 1;
    const EMaxHappiness: u64 = 2;
    const EInsufficientFunds: u64 = 3;
    const ELimitReached: u64 = 4;

    fun init(otw: PET_NFT, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        let keys = vector[string::utf8(b"name"), string::utf8(b"image_url"), string::utf8(b"sprite_url")];
        let values = vector[string::utf8(b"{name}"), string::utf8(b"{image_url}"), string::utf8(b"{sprite_url}")];

        let mut display = display::new_with_fields<PetNFT>(&publisher, keys, values, ctx);
        display::update_version(&mut display);

        let global_config = GlobalConfig {
            id: object::new(ctx),
            custom_mint_limit: 10, 
            custom_mint_count: 0,
            base_slot_fee: 10000 * 1000000000,   // 10,000 MIPET cố định
            treasury_address: tx_context::sender(ctx), // Mặc định là người deploy
            templates: vector::empty<ID>(),
        };
        
        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(global_config);
    }

    /// Admin điều chỉnh phí
    public fun update_config(
        _: &AdminCap,
        config: &mut GlobalConfig,
        base_fee: u64,
    ) {
        config.base_slot_fee = base_fee;
    }

    /// Admin điều chỉnh treasury
    public fun update_treasury(
        _: &AdminCap,
        config: &mut GlobalConfig,
        new_treasury: address,
    ) {
        config.treasury_address = new_treasury;
    }

    /// Admin tăng giới hạn đúc
    public fun increase_mint_limit(_: &AdminCap, config: &mut GlobalConfig, amount: u64) {
        config.custom_mint_limit = config.custom_mint_limit + amount;
    }

    /// MUA SLOT ĐÚC (Giá cố định)
    public entry fun buy_mint_slot(
        config: &mut GlobalConfig,
        payment: &mut Coin<PET_TOKEN>,
        ctx: &mut TxContext
    ) {
        let current_price = config.base_slot_fee;
        assert!(coin::value(payment) >= current_price, EInsufficientFunds);

        let fee_coin = coin::split(payment, current_price, ctx);
        transfer::public_transfer(fee_coin, config.treasury_address);

        // Gửi Slot cho người mua
        let slot = MintSlot { id: object::new(ctx) };
        transfer::public_transfer(slot, tx_context::sender(ctx));
    }

    /// ĐÚC PET BẰNG SLOT (Secure Randomness)
    public entry fun mint_custom_with_slot(
        config: &mut GlobalConfig,
        slot: MintSlot,
        name: vector<u8>,
        image_url: vector<u8>,
        image_blob_id: ID,
        sprite_url: vector<u8>,
        sprite_blob_id: ID,
        slug: vector<u8>,
        clock: &Clock,
        random: &Random,
        ctx: &mut TxContext
    ) {
        assert!(config.custom_mint_count < config.custom_mint_limit, ELimitReached);
        
        let MintSlot { id: slot_id } = slot;
        object::delete(slot_id);

        let perfection = roll_perfection_v2(random, ctx);
        config.custom_mint_count = config.custom_mint_count + 1;

        let pet = PetNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            image_url: string::utf8(image_url),
            image_blob_id,
            sprite_url: string::utf8(sprite_url),
            sprite_blob_id,
            slug: string::utf8(slug),
            level: 1,
            experience: 0,
            happiness: 100,
            born_at: clock::timestamp_ms(clock),
            perfection_score: perfection,
            is_custom: true,
        };
        transfer::public_transfer(pet, tx_context::sender(ctx));
    }

    /// Admin tạo mẫu Pet mới để bán
    public fun create_template(
        _: &AdminCap,
        config: &mut GlobalConfig,
        name: vector<u8>,
        img: vector<u8>,
        img_blob: ID,
        sprite: vector<u8>,
        sprite_blob: ID,
        price: u64,
        ctx: &mut TxContext
    ) {
        let template = PetTemplate {
            id: object::new(ctx),
            name: string::utf8(name),
            image_url: string::utf8(img),
            image_blob_id: img_blob,
            sprite_url: string::utf8(sprite),
            sprite_blob_id: sprite_blob,
            price,
        };
        let template_id = object::id(&template);
        vector::push_back(&mut config.templates, template_id);
        transfer::public_share_object(template);
    }

    /// Người dùng mua Pet Official từ Store (Secure Randomness)
    public entry fun buy_pet(
        config: &GlobalConfig,
        template: &PetTemplate, 
        payment: Coin<SUI>, 
        clock: &Clock, 
        random: &Random,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&payment) >= template.price, EInsufficientFunds);
        
        let perfection = roll_perfection_v2(random, ctx);
        let pet = PetNFT {
            id: object::new(ctx), 
            name: template.name, 
            image_url: template.image_url, 
            image_blob_id: template.image_blob_id,
            sprite_url: template.sprite_url,
            sprite_blob_id: template.sprite_blob_id,
            slug: template.name, 
            level: 1, 
            experience: 0,
            happiness: 100, 
            born_at: clock::timestamp_ms(clock),
            perfection_score: perfection, 
            is_custom: false,
        };
        transfer::public_transfer(payment, config.treasury_address);
        transfer::public_transfer(pet, tx_context::sender(ctx));
    }

    /// Secure Randomness roll using Sui's Random module
    fun roll_perfection_v2(random: &Random, ctx: &mut TxContext): u64 {
        let mut gen = random::new_generator(random, ctx);
        let roll = random::generate_u64_in_range(&mut gen, 0, 10000);
        
        if (roll < 8000) { 
            random::generate_u64_in_range(&mut gen, 1, 80001)
        } 
        else if (roll < 9500) { 
            80000 + random::generate_u64_in_range(&mut gen, 1, 15001)
        }
        else if (roll < 9990) { 
            95000 + random::generate_u64_in_range(&mut gen, 1, 4001)
        }
        else { 
            99000 + random::generate_u64_in_range(&mut gen, 1, 1001)
        }
    }

    public fun perfection_score(pet: &PetNFT): u64 { pet.perfection_score }
    public fun level(pet: &PetNFT): u64 { pet.level }
    public fun experience(pet: &PetNFT): u64 { pet.experience }
    public fun happiness(pet: &PetNFT): u64 { pet.happiness }
    public fun born_at(pet: &PetNFT): u64 { pet.born_at }
    
    public fun level_up(pet: &mut PetNFT) { pet.level = pet.level + 1; }
    public fun update_happiness(pet: &mut PetNFT, amount: u64) { assert!(amount <= 100, EMaxHappiness); pet.happiness = amount; }
    public fun burn(pet: PetNFT) {
        let PetNFT { 
            id, 
            name: _, 
            image_url: _, 
            image_blob_id: _, 
            sprite_url: _, 
            sprite_blob_id: _, 
            slug: _, 
            level: _, 
            experience: _,
            happiness: _, 
            born_at: _, 
            perfection_score: _, 
            is_custom: _ 
        } = pet;
        object::delete(id);
    }
    
    public entry fun send_message(config: &GlobalConfig, pet: &mut PetNFT, payment: &mut Coin<SUI>, recipient: address, message: vector<u8>, ctx: &mut TxContext) {
        let amount = coin::value(payment); 
        let fee_amount = amount / 100; // 1% fee
        
        if (fee_amount > 0) {
            let fee_coin = coin::split(payment, fee_amount, ctx);
            transfer::public_transfer(fee_coin, config.treasury_address);
        };
        
        let sent_amount = coin::value(payment);
        let sent_coin = coin::split(payment, sent_amount, ctx);
        transfer::public_transfer(sent_coin, recipient);
        
        // Tính kinh nghiệm: 1 SUI (10^9 MIST) = 100 EXP -> 1 EXP = 10,000,000 MIST (0.01 SUI).
        // EXP dựa trên tổng amount gốc để khuyến khích
        let exp_gained = amount / 10000000;
        if (exp_gained > 0) {
            pet.experience = pet.experience + exp_gained;
            // Vòng lặp thăng cấp (Cần level * 100 EXP)
            while (pet.experience >= pet.level * 100) {
                pet.experience = pet.experience - pet.level * 100;
                pet.level = pet.level + 1;
            };
        };

        event::emit(MessageEvent { sender: tx_context::sender(ctx), recipient, amount, message: string::utf8(message), pet_slug: pet.name, pet_image: pet.image_url });
    }
    public entry fun bonk_pet(
        config: &GlobalConfig,
        my_pet: &mut PetNFT, 
        payment: &mut Coin<PET_TOKEN>, 
        target: address, 
        ctx: &mut TxContext
    ) {
        let fee = 100 * 1000000000; 
        let fee_coin = coin::split(payment, fee, ctx); 
        transfer::public_transfer(fee_coin, config.treasury_address);
        
        // Gõ đầu nhận cố định 50 EXP
        let exp_gained = 50;
        my_pet.experience = my_pet.experience + exp_gained;
        while (my_pet.experience >= my_pet.level * 100) {
            my_pet.experience = my_pet.experience - my_pet.level * 100;
            my_pet.level = my_pet.level + 1;
        };

        event::emit(BonkEvent { bonker: tx_context::sender(ctx), target, fee, pet_slug: my_pet.name, pet_image: my_pet.image_url });
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(PET_NFT {}, ctx);
    }
}
