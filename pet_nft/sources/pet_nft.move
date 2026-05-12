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

    public struct PET_NFT has drop {}

    /// NFT chính
    public struct PetNFT has key, store {
        id: UID,
        name: String,
        image_url: String,
        slug: String,
        level: u64,
        happiness: u64,
        born_at: u64,
        perfection_score: u64, // 1 to 100,000 (0.001% to 100%)
    }
    
    /// Event cho tin nhắn kèm tiền
    public struct MessageEvent has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        message: String,
        pet_slug: String,
        pet_image: String,
    }

    /// Event khi tặng quà PET token
    public struct GiftEvent has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        message: String,
        pet_slug: String,
        pet_image: String,
    }

    /// Event khi gõ đầu PET
    public struct BonkEvent has copy, drop {
        bonker: address,
        target: address,
        fee: u64,
        pet_slug: String,
        pet_image: String,
    }

    /// Error codes
    const ENotOwner: u64 = 1;
    const EMaxHappiness: u64 = 2;

    fun init(otw: PET_NFT, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"image_url"),
            string::utf8(b"description"),
            string::utf8(b"project_url"),
        ];

        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{image_url}"),
            string::utf8(b"A lovely MiniPet focusing companion!"),
            string::utf8(b"https://minipet.app"),
        ];

        let mut display = display::new_with_fields<PetNFT>(
            &publisher, keys, values, ctx
        );

        display::update_version(&mut display);

        // Tạo AdminCap và chuyển cho người deploy
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(PET_NFT {}, ctx);
    }

    /// Mint NFT, chuyển cho caller
    public fun mint_pet(
        _: &AdminCap,
        name: vector<u8>,
        image_url: vector<u8>,
        slug: vector<u8>,
        clock: &Clock,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        
        // Tạo tính ngẫu nhiên giả từ ID
        let seed = hash::blake2b256(&address::to_bytes(object::uid_to_address(&id)));
        let mut i = 0;
        let mut random_val: u64 = 0;
        while (i < 8) {
            random_val = (random_val << 8) | (*vector::borrow(&seed, i) as u64);
            i = i + 1;
        };

        // Công thức tạo độ hiếm: x = random(1-1000). perfection = x^2 / 10
        // Điều này làm cho các giá trị thấp xuất hiện nhiều, giá trị cao (gần 100.000) cực hiếm.
        let x = (random_val % 1000) + 1;
        let perfection = (x * x) / 10 + 1;

        let pet = PetNFT {
            id,
            name: string::utf8(name),
            image_url: string::utf8(image_url),
            slug: string::utf8(slug),
            level: 1,
            happiness: 100,
            born_at: clock::timestamp_ms(clock),
            perfection_score: perfection,
        };
        transfer::public_transfer(pet, recipient);
    }

    /// Tăng level (chỉ owner)
    public fun level_up(pet: &mut PetNFT) {
        pet.level = pet.level + 1;
    }

    /// Update happiness 0-100
    public fun update_happiness(pet: &mut PetNFT, amount: u64) {
        assert!(amount <= 100, EMaxHappiness);
        pet.happiness = amount;
    }

    /// Tăng counter sessions (Đã bỏ, giữ hàm rỗng hoặc xóa để tránh lỗi App cũ)
    public fun record_focus_session(_pet: &mut PetNFT) {
        // pet.total_focus_sessions = pet.total_focus_sessions + 1;
    }

    /// Xóa NFT
    public fun burn(pet: PetNFT) {
        let PetNFT {
            id,
            name: _,
            image_url: _,
            slug: _,
            level: _,
            happiness: _,
            born_at: _,
            perfection_score: _
        } = pet;
        object::delete(id);
    }

    /// Gửi tiền kèm lời nhắn
    public entry fun send_message(
        payment: Coin<SUI>,
        recipient: address,
        message: vector<u8>,
        pet_slug: vector<u8>,
        pet_image: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount = coin::value(&payment);
        
        transfer::public_transfer(payment, recipient);
        
        event::emit(MessageEvent {
            sender,
            recipient,
            amount,
            message: string::utf8(message),
            pet_slug: string::utf8(pet_slug),
            pet_image: string::utf8(pet_image),
        });
    }

    /// Tặng quà (Bằng SUI)
    public entry fun send_gift(
        payment: Coin<SUI>,
        recipient: address,
        message: vector<u8>,
        pet_slug: vector<u8>,
        pet_image: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount = coin::value(&payment);
        
        transfer::public_transfer(payment, recipient);
        
        event::emit(GiftEvent {
            sender,
            recipient,
            amount,
            message: string::utf8(message),
            pet_slug: string::utf8(pet_slug),
            pet_image: string::utf8(pet_image),
        });
    }

    /// Gõ đầu Pet (Tốn phí 100 PET cho nền tảng)
    public entry fun bonk_pet(
        payment: &mut Coin<PET_TOKEN>,
        treasury_address: address, // Địa chỉ nhận phí của nền tảng
        target: address,
        pet_slug: vector<u8>,
        pet_image: vector<u8>,
        ctx: &mut TxContext
    ) {
        let bonker = tx_context::sender(ctx);
        let fee_amount = 100 * 1000000000; // 100 PET (với 9 decimals)
        
        let fee_coin = coin::split(payment, fee_amount, ctx);
        transfer::public_transfer(fee_coin, treasury_address);
        
        event::emit(BonkEvent {
            bonker,
            target,
            fee: fee_amount,
            pet_slug: string::utf8(pet_slug),
            pet_image: string::utf8(pet_image),
        });
    }
}
