# MiniPet Sui Move Smart Contracts 📜
Sui Move smart contracts managing the core economy, token, and NFTs of the MiniPet ecosystem.

---

## 📦 Move Modules

The package contains two main Move sub-packages:

### 1. `pet_token` (MIPET)
- Defines the `pet_token::MIPET` coin type, representing the utility token of the ecosystem.
- Provides standard coin minting controls via the `TreasuryCap<MIPET>` owned by the admin.
- Used by users to purchase custom pet minting slots.

### 2. `pet_nft`
- Defines the `PetNFT` object, which represents the user's desktop pixel companion.
- **Admin Configuration (`GlobalConfig`)**:
  - Tracks the base fee (in MIPET) required to buy a mint slot.
  - Limits and tracks the total number of custom pet creations.
  - Sets the `treasury_address` receiving fees.
- **Mint Slot (`MintSlot`)**:
  - A voucher purchased by users. Owning a `MintSlot` enables custom uploads and transaction sponsorships.
- **Admin Capabilities (`AdminCap`)**:
  - Held by the owner of the contract. Allows modifying global fees, increasing custom limits, updating treasury addresses, and registering new official pet templates.

---

## 🚀 Compilation & Deployment Guide

Ensure you have the [Sui CLI installed](https://docs.sui.io/guides/developer/getting-started/sui-install).

### 1. Build Contracts
```bash
# Compile the pet_token coin contract
cd pet_token
sui move build

# Compile the main pet_nft contract
cd ../pet_nft
sui move build
```

### 2. Run Unit Tests
```bash
cd pet_nft
sui move test
```

### 3. Deploy to Sui Testnet
```bash
# Switch environment to testnet
sui client active-env testnet

# Publish the package
sui client publish --gas-budget 100000000
```
Save the returned **Package ID**, **GlobalConfig ID**, and **AdminCap ID** to update the backend and frontend environment files.
