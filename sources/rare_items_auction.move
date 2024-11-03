module rare_items_auction::rare_items_auction {
    // Importing necessary modules
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use std::string::String;
    use sui::clock::{Self, Clock};
    use std::option::{none, some};
    use sui::tx_context::{Self, TxContext};

    // Updated descriptive error codes
    const EUnauthorized: u64 = 1;               // Error when unauthorized access is detected.
    const EEndTimeNotReached: u64 = 2;          // Error when auction has not yet ended.
    const EInsufficientBid: u64 = 3;            // Error when bid is insufficient.
    const EInvalidBid: u64 = 4;                 // Error when bid is lower than the highest bid.
    const EAlreadyClaimed: u64 = 5;             // Error when bid has already been claimed.
    const ENoAuctionsAvailable: u64 = 6;        // Error when there are no available auctions.
    const EReserveNotMet: u64 = 7;              // Error when highest bid does not meet reserve price.
    
    // Structs for auction lifecycle management
    public struct AuctionHouseCap has key, store {
        id: UID,
        auctions: vector<ID>,
        wallet: Balance<SUI>,
    }

    public struct Item has key, store {
        id: UID,
        owner: address,
        name: String,
        item_type: String,
        description: String,
        metadata: String,
    }

    public struct Auction has key, store {
        id: UID,
        item_id: UID,
        seller: address,
        starting_price: u64,
        end_time: u64,
        reserve_price: u64,
        highest_bidder: Option<address>,
        highest_bid: u64,
        bids: vector<Bid>,
        pool: Balance<SUI>,
    }

    public struct Bid has key, store {
        id: UID,
        bidder: address,
        amount: u64,
    }

    // Initializes the auction house
    public fun init(ctx: &mut TxContext) {
        let auction_house = AuctionHouseCap {
            id: object::new(ctx),
            auctions: vector::empty<ID>(),
            wallet: balance::zero<SUI>(),
        };
        transfer::transfer(auction_house, tx_context::sender(ctx));
    }

    // Adds a new item
    public fun add_item(
        owner: address,
        name: String,
        item_type: String,
        description: String,
        metadata: String,
        ctx: &mut TxContext
    ) : Item {
        let id = object::new(ctx);
        Item { id, owner, name, item_type, description, metadata }
    }

    // Adds a new auction
    public fun add_auction(
        auction_house: &mut AuctionHouseCap,
        item: &Item,
        seller: address,
        starting_price: u64,
        end_time: u64,
        reserve_price: u64,
        ctx: &mut TxContext
    ) {
        assert!(item.owner == tx_context::sender(ctx), EUnauthorized);
        let id = object::new(ctx);
        let auction = Auction {
            id,
            item_id: item.id,
            seller,
            starting_price,
            end_time,
            reserve_price,
            highest_bidder: none(),
            highest_bid: 0,
            bids: vector::empty(),
            pool: balance::zero<SUI>(),
        };
        transfer::share_object(auction);
        vector::push_back(&mut auction_house.auctions, id);
    }

    // Helper function to check if the auction is active
    public fun is_auction_active(auction: &Auction, clock: &Clock): bool {
        clock::timestamp_ms(clock) < auction.end_time
    }

    // Place a bid on an auction
    public fun place_bid(
        auction: &mut Auction,
        bidder: address,
        amount: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(is_auction_active(auction, clock), EEndTimeNotReached);
        let amount_u64 = coin::value(&amount);
        assert!(amount_u64 > auction.highest_bid, EInvalidBid);
        assert!(amount_u64 >= auction.reserve_price, EReserveNotMet);

        let id = object::new(ctx);
        let bid = Bid { id, bidder, amount: amount_u64 };
        let bid_amount = coin::into_balance(amount);
        balance::join(&mut auction.pool, bid_amount);

        auction.highest_bid = amount_u64;
        auction.highest_bidder = some(bidder);
        auction.bids.push_back(bid);
    }

    // Finalize auction by accepting the highest bid
    public fun accept_highest_bid(
        auction: &mut Auction,
        item: &mut Item,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!is_auction_active(auction, clock), EEndTimeNotReached);
        assert!(auction.highest_bid >= auction.reserve_price, EReserveNotMet);

        let highest_bidder = match auction.highest_bidder {
            some(addr) => addr,
            none => abort(ENoAuctionsAvailable),
        };

        item.owner = highest_bidder;
        let bid_amount = coin::take(&mut auction.pool, auction.highest_bid, ctx);
        transfer::public_transfer(bid_amount, auction.seller);
    }

    // Withdraw bid by a bidder
    public fun withdraw_bid(
        auction: &mut Auction,
        bid: &mut Bid,
        ctx: &mut TxContext
    ) {
        assert!(bid.bidder == tx_context::sender(ctx), EUnauthorized);
        let bid_amount = coin::take(&mut auction.pool, bid.amount, ctx);
        transfer::public_transfer(bid_amount, bid.bidder);
    }

    // Seller withdraws remaining funds from the auction pool
    public fun withdraw_pool(
        auction: &mut Auction,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(auction.seller == tx_context::sender(ctx), EUnauthorized);
        assert!(balance::value(&auction.pool) >= amount, EInsufficientBid);

        let withdrawn = coin::take(&mut auction.pool, amount, ctx);
        transfer::public_transfer(withdrawn, auction.seller);
    }        
}
