# ChainTrail NFT Smart Contract

## Overview

**ChainTrail** is a SIP-009 compliant NFT smart contract that combines advanced token management with an integrated marketplace. It allows users to mint unique NFTs, trade them securely, and manage metadata, all while ensuring marketplace governance and fee collection.

## Features

* **SIP-009 NFT Compliance**: Implements the required NFT trait functions (`transfer`, `get-owner`, `get-last-token-id`, `get-token-uri`).
* **Minting**: Users can mint NFTs with associated metadata (URL and creator).
* **Ownership Management**: Secure transfer of NFTs between principals with ownership validation.
* **Marketplace**:

  * List NFTs for sale with price and expiry.
  * Buy listed NFTs with automatic fee calculation and transfer.
  * Unlist or update expiry for listed tokens.
* **Fees & Governance**: Marketplace fee (default 2.5%) is collected and adjustable by the contract owner.
* **Admin Controls**: Pause/unpause the marketplace, adjust fees, and manage platform stability.

## Data Structures

* **token-metadata**: Stores NFT details including owner, metadata URL, and creator.
* **token-listings**: Stores marketplace listing details such as price, seller, and expiry.

## Error Codes

* `u100`: Owner-only function.
* `u101`: Caller is not the token owner.
* `u102`: Token not found.
* `u103`: Listing not found.
* `u104`: Insufficient funds.
* `u105`: Invalid price.
* `u106`: Marketplace is paused.
* `u997`: Invalid expiry.
* `u998`: Empty metadata URL.
* `u999`: Invalid recipient (contract owner as recipient not allowed).

## Functions

### Core NFT

* `transfer (token-id sender recipient)`: Transfer NFT from one principal to another.
* `mint (metadata-url)`: Mint a new NFT with metadata.
* `get-owner (token-id)`: Get the owner of a token.
* `get-last-token-id ()`: Retrieve the last minted token ID.
* `get-token-uri (token-id)`: Get the metadata URL of a token.

### Marketplace

* `list-token (token-id price expiry)`: List a token for sale.
* `unlist-token (token-id)`: Remove a token from marketplace.
* `buy-token (token-id)`: Purchase a listed token.
* `update-expiry (token-id new-expiry)`: Update expiry of a listing.

### Admin

* `set-marketplace-fee (new-fee)`: Set new marketplace fee (max 10%).
* `toggle-marketplace-pause ()`: Pause or resume marketplace operations.

### Read-only

* `get-token-metadata (token-id)`: Fetch metadata of a token.
* `get-token-listing (token-id)`: Fetch listing details of a token.

## Usage

1. **Minting**: Call `mint` with a valid metadata URL to create a new NFT.
2. **Trading**:

   * List tokens with `list-token`.
   * Other users can buy them using `buy-token`.
3. **Administration**: Contract owner can set fees, pause the marketplace, or update listing expiries.

This contract provides a full-featured NFT ecosystem with trading, governance, and metadata handling under the **ChainTrail** framework.
