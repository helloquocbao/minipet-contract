module pet_token::pet_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    public struct PET_TOKEN has drop {}

    fun init(witness: PET_TOKEN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,                  // decimals
            b"MMOT",            // symbol
            b"Mini Monter",     // name
            b"Focus to earn MMOT and grow your monsters!", // description
            option::none(),     // icon_url
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
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

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(PET_TOKEN {}, ctx);
    }
}
