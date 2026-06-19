module pet_token::pet_token {
    use std::ascii;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    public struct PET_TOKEN has drop {}

    /// Faucet config - shared object cho phép user claim token trên testnet
    public struct FaucetConfig has key {
        id: sui::object::UID,
        claim_amount: u64,          // Số token claim mỗi lần (default: 10001 MIPET)
        cooldown_epochs: u64,       // Cooldown giữa các lần claim (epochs)
    }

    fun init(witness: PET_TOKEN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,                  // decimals
            b"MIPET",           // symbol
            b"MiniPet",         // name
            b"The official currency of MiniPet ecosystem. Focus, grow, and trade!", // description
            option::some(sui::url::new_unsafe(ascii::string(b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/rldMZTItP-B0S2a8tXrylPEZjThnRUQT0vUAAvKFFJ4"))),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));

        // Tạo faucet config shared
        let faucet = FaucetConfig {
            id: sui::object::new(ctx),
            claim_amount: 10001 * 1000000000, // 10001 MIPET
            cooldown_epochs: 0,              // Không cooldown trên testnet
        };
        transfer::share_object(faucet);
    }

    // Chỉ admin (treasury holder) mới mint được
    public fun mint(
        treasury: &mut TreasuryCap<PET_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury, amount, recipient, ctx);
    }

    // Burn token
    public fun burn(treasury: &mut TreasuryCap<PET_TOKEN>, coin: Coin<PET_TOKEN>) {
        coin::burn(treasury, coin);
    }

    /// Testnet faucet: ai cũng claim được token miễn phí để test
    public entry fun claim_token(
        treasury: &mut TreasuryCap<PET_TOKEN>,
        faucet: &FaucetConfig,
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury, faucet.claim_amount, tx_context::sender(ctx), ctx);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(PET_TOKEN {}, ctx);
    }
}
