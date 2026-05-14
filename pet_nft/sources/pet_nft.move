module pet_nft::pet_nft {
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::display;
    use sui::package;
    use sui::hash;
    use sui::address;
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use pet_token::pet_token::PET_TOKEN;

    /// Admin cap để mint (chỉ app mới có thể mint)
    public struct AdminCap has key { id: UID }

    /// Cấu hình toàn cục để quản lý giới hạn
    public struct GlobalConfig has key {
        id: UID,
        custom_mint_limit: u64,
        custom_mint_count: u64,
        base_slot_fee: u64,     // Phí cố định cho 1 slot
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
        image_url: String,  
        sprite_url: String, 
        slug: String,
        level: u64,
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
        sprite_url: String,
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
            custom_mint_limit: 100, 
            custom_mint_count: 0,
            base_slot_fee: 10000 * 1000000000,   // 10,000 MIPET cố định
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

    /// Admin tăng giới hạn đúc
    public fun increase_mint_limit(_: &AdminCap, config: &mut GlobalConfig, amount: u64) {
        config.custom_mint_limit = config.custom_mint_limit + amount;
    }

    /// MUA SLOT ĐÚC (Giá cố định)
    public entry fun buy_mint_slot(
        config: &mut GlobalConfig,
        payment: &mut Coin<PET_TOKEN>,
        treasury: address,
        ctx: &mut TxContext
    ) {
        let current_price = config.base_slot_fee;
        assert!(coin::value(payment) >= current_price, EInsufficientFunds);

        let fee_coin = coin::split(payment, current_price, ctx);
        transfer::public_transfer(fee_coin, treasury);

        // Gửi Slot cho người mua
        let slot = MintSlot { id: object::new(ctx) };
        transfer::public_transfer(slot, tx_context::sender(ctx));
    }

    /// ĐÚC PET BẰNG SLOT
    public entry fun mint_custom_with_slot(
        config: &mut GlobalConfig,
        slot: MintSlot,
        name: vector<u8>,
        image_url: vector<u8>,
        sprite_url: vector<u8>,
        slug: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(config.custom_mint_count < config.custom_mint_limit, ELimitReached);
        
        let MintSlot { id: slot_id } = slot;
        object::delete(slot_id);

        let id = object::new(ctx);
        let perfection = roll_perfection(&id);
        config.custom_mint_count = config.custom_mint_count + 1;

        let pet = PetNFT {
            id,
            name: string::utf8(name),
            image_url: string::utf8(image_url),
            sprite_url: string::utf8(sprite_url),
            slug: string::utf8(slug),
            level: 1,
            happiness: 100,
            born_at: clock::timestamp_ms(clock),
            perfection_score: perfection,
            is_custom: true,
        };
        transfer::public_transfer(pet, tx_context::sender(ctx));
    }

    /// Admin tạo mẫu Pet mới để bán
    public fun create_template(_: &AdminCap, name: vector<u8>, img: vector<u8>, sprite: vector<u8>, price: u64, ctx: &mut TxContext) {
        let template = PetTemplate {
            id: object::new(ctx),
            name: string::utf8(name),
            image_url: string::utf8(img),
            sprite_url: string::utf8(sprite),
            price,
        };
        transfer::public_share_object(template);
    }

    /// Người dùng mua Pet Official từ Store
    public entry fun buy_pet(template: &PetTemplate, payment: Coin<SUI>, clock: &Clock, treasury: address, ctx: &mut TxContext) {
        assert!(coin::value(&payment) >= template.price, EInsufficientFunds);
        let id = object::new(ctx);
        let perfection = roll_perfection(&id);
        let pet = PetNFT {
            id, name: template.name, image_url: template.image_url, sprite_url: template.sprite_url,
            slug: template.name, level: 1, happiness: 100, born_at: clock::timestamp_ms(clock),
            perfection_score: perfection, is_custom: false,
        };
        transfer::public_transfer(payment, treasury);
        transfer::public_transfer(pet, tx_context::sender(ctx));
    }

    fun roll_perfection(id: &UID): u64 {
        let seed = hash::blake2b256(&address::to_bytes(object::uid_to_address(id)));
        let mut i = 0; let mut val: u64 = 0;
        while (i < 8) { val = (val << 8) | (*vector::borrow(&seed, i) as u64); i = i + 1; };
        let roll = val % 10000;
        if (roll < 8000) { (val % 80000) + 1 } 
        else if (roll < 9500) { 80000 + (val % 15000) + 1 }
        else if (roll < 9990) { 95000 + (val % 4000) + 1 }
        else { 99000 + (val % 1000) + 1 }
    }

    public fun level_up(pet: &mut PetNFT) { pet.level = pet.level + 1; }
    public fun update_happiness(pet: &mut PetNFT, amount: u64) { assert!(amount <= 100, EMaxHappiness); pet.happiness = amount; }
    public fun burn(pet: PetNFT) {
        let PetNFT { id, name: _, image_url: _, sprite_url: _, slug: _, level: _, happiness: _, born_at: _, perfection_score: _, is_custom: _ } = pet;
        object::delete(id);
    }
    
    public entry fun send_message(pet: &PetNFT, payment: Coin<SUI>, recipient: address, message: vector<u8>, ctx: &mut TxContext) {
        let amount = coin::value(&payment); transfer::public_transfer(payment, recipient);
        event::emit(MessageEvent { sender: tx_context::sender(ctx), recipient, amount, message: string::utf8(message), pet_slug: pet.name, pet_image: pet.image_url });
    }
    public entry fun bonk_pet(my_pet: &PetNFT, payment: &mut Coin<PET_TOKEN>, treasury: address, target: address, ctx: &mut TxContext) {
        let fee = 100 * 1000000000; let fee_coin = coin::split(payment, fee, ctx); transfer::public_transfer(fee_coin, treasury);
        event::emit(BonkEvent { bonker: tx_context::sender(ctx), target, fee, pet_slug: my_pet.name, pet_image: my_pet.image_url });
    }
}
