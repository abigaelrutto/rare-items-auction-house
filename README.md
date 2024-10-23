# Rare Items Auction House

## Overview

The **Rare Items Auction House** is a decentralized auction platform implemented on the **SUI blockchain**. It allows users to auction rare and unique items, represented as NFTs, in a transparent and trustless environment. This smart contract handles the complete auction lifecycle, including adding items, placing bids, accepting bids, and transferring funds and ownership once an auction is completed.

## Features

- **Auction Creation**: Users can list rare items (NFTs) for auction with a specified starting price, reserve price, and auction duration.
- **Bidding**: Users can place bids on available auctions, with automatic rejection of bids lower than the current highest bid.
- **Escrow**: Funds are held in an escrow pool until the auction ends and the highest bid is accepted or withdrawn.
- **Item Transfer**: Upon successful bidding, ownership of the item is automatically transferred to the highest bidder.
- **Bid Withdrawal**: Users can withdraw unclaimed bids or reclaim their funds if their bid is not the highest.
- **Seller Payout**: Sellers can withdraw the auction proceeds after the auction is finalized.

## Smart Contract Structure

### Modules and Libraries

- **sui::sui::SUI**: The native SUI token is used for transactions and bid payments.
- **sui::coin::Coin**: Manages coin operations and balances.
- **sui::balance::Balance**: Handles operations on balances of SUI tokens.
- **sui::clock::Clock**: Manages time-sensitive operations, especially auction durations.

### Core Structs

1. **AuctionHouseCap**: Represents the auction house itself, managing multiple auctions and storing a wallet balance for the auction house.
   - `id`: Unique identifier for the auction house.
   - `auctions`: List of all auction IDs managed by the auction house.
   - `wallet`: Balance holding the collected funds from auctions.

2. **Item**: Represents a rare item being auctioned.
   - `id`: Unique identifier (UID) for the item.
   - `owner`: Address of the item's current owner.
   - `name`: Name of the item (e.g., "Mona Lisa").
   - `item_type`: Type of the item (e.g., painting, sculpture).
   - `description`: Detailed description of the item.
   - `metadata`: Additional metadata (e.g., creator, authenticity).

3. **Auction**: Represents an active auction, containing bids, item details, and auction lifecycle information.
   - `id`: Unique identifier for the auction.
   - `item_id`: UID of the item being auctioned.
   - `seller`: Address of the seller.
   - `starting_price`: Starting price for the auction.
   - `end_time`: Auction end time (timestamp in milliseconds).
   - `reserve_price`: Minimum acceptable bid for the item.
   - `highest_bidder`: Optional address of the current highest bidder.
   - `highest_bid`: The current highest bid in SUI tokens.
   - `bids`: Vector of all bids placed on the auction.
   - `pool`: Pool balance for holding bids in escrow.

4. **Bid**: Represents a bid placed by a user in an auction.
   - `id`: Unique identifier for the bid.
   - `bidder`: Address of the bidder.
   - `amount`: Amount of the bid in SUI tokens.
   - `is_claimed`: Boolean flag indicating whether the bid has been claimed.

### Error Codes

- `EEndTimeNotReached`: Auction end time has not been reached.
- `ENotBidder`: Caller is not the bidder or authorized party.
- `EInsufficientBid`: The highest bid does not meet the reserve price.
- `EInvalidBid`: Bid placed is lower than the current highest bid.
- `EClaimedBid`: Bid has already been claimed.
- `ENoAuctions`: No auctions are currently available.

## Key Functions

1. **`init(ctx: &mut TxContext)`**  
   Initializes the auction house by creating an `AuctionHouseCap` object with an empty list of auctions and a zero balance.

2. **`add_item(owner: address, name: String, item_type: String, description: String, metadata: String, ctx: &mut TxContext)`**  
   Adds a new item (NFT) to the auction house. This item can later be auctioned off.

3. **`add_auction(auction_house: &mut AuctionHouseCap, item: &Item, seller: address, item_id: UID, starting_price: u64, end_time: u64, reserve_price: u64, ctx: &mut TxContext)`**  
   Lists an item for auction by the seller with a starting price and a reserve price.

4. **`place_bid(auction: &mut Auction, bidder: address, amount: Coin<SUI>, clock: &Clock, ctx: &mut TxContext)`**  
   Allows users to place a bid on a listed auction. The bid amount must exceed the current highest bid.

5. **`accept_bid(auction: &mut Auction, bid: &mut Bid, item: &mut Item, clock: &Clock, ctx: &mut TxContext)`**  
   Allows the seller to accept the highest bid after the auction has ended and transfer the item to the highest bidder.

6. **`withdraw_bid(auction: &mut Auction, bid: &mut Bid, ctx: &mut TxContext)`**  
   Allows a bidder to withdraw their bid and reclaim their funds if the bid has not been claimed.

7. **`withdraw_pool(auction: &mut Auction, amount: u64, ctx: &mut TxContext)`**  
   Allows the seller to withdraw funds from the auction pool after the auction is completed.

## Installation and Setup

1. Install SUI development tools and libraries.
2. Clone this repository.
3. Compile the contract using the SUI development environment.
4. Deploy the contract to the SUI blockchain.

## How to Use

1. **Initialize Auction House**: Call the `init` function to create an auction house.
2. **Add Items**: Add items (NFTs) to the contract using the `add_item` function.
3. **Create Auction**: List an item for auction using the `add_auction` function.
4. **Place Bid**: Users can place bids on active auctions using the `place_bid` function.
5. **Accept Bid**: Sellers can accept the highest bid after the auction ends using the `accept_bid` function.
6. **Withdraw Funds**: Both bidders and sellers can withdraw their funds using the `withdraw_bid` and `withdraw_pool` functions, respectively.

## Contributing

Feel free to open issues or submit pull requests for improvements and bug fixes. We welcome community contributions.

## License

This project is licensed under the MIT License. See the `LICENSE` file for more details.

```

This README outlines the structure, functionality, and usage of the **Rare Items Auction House** decentralized contract, providing a comprehensive guide for developers and users.
