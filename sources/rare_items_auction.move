// Decentralized Rare Items Auction House
module auction::rare_items_auction {
    // This module defines the rare items auction contract.

    // Importing necessary modules from the standard library and SUI.
    use sui::sui::SUI;
    use sui::coin::{Self, Coin}; // Manages coins and balances in the SUI blockchain.
    use sui::balance::{Self, Balance, zero}; // Handles balance operations.
    use std::string::String; // Importing string utilities.
    use sui::clock::{Self, Clock}; // For managing time-based operations (like auction timing).
    use std::option::{some}; // Optional values to handle cases like the highest bid being absent.
    use sui::event;
    use sui::object::{uid_to_inner};

    // Define error codes
    const EEndTimeNotReached: u64 = 0;
    const ENotBidder: u64 = 2;
    const EInvalidBid: u64 = 6;
    const EClaimedBid: u64 = 7;
    const ENoAuctions: u64 = 8;
    const ENotOwner: u64 = 9;
    const EInvalidWithdrawalAmount: u64 = 10;
    const EItemNotOwnedBySeller: u64 = 12;

    // Structs definition for the rare items auction contract

    // Struct to store information about the auction house.
    public struct AuctionHouseCap has key, store {
        id: UID, // Unique identifier for the auction house.
        auctions: vector<ID>, // Vector to store the IDs of auctions managed by the auction house.
        wallet: Balance<SUI>, // Balance representing the total funds collected by the auction house.
    }

    // Struct to represent an auctioned item.
    public struct Item has key, store {
        id: UID, // Unique identifier for the item (NFT).
        owner: address, // Address of the current owner of the item.
        name: String, // Name of the item (e.g., "Mona Lisa").
        item_type: String, // Type of the item (e.g., painting, sculpture).
        description: String, // Detailed description of the item.
        metadata: String, // Additional metadata (e.g., creator, authenticity).
    }

    // Struct to represent an auction.
    public struct Auction has key, store {
        id: UID, // Unique identifier for the auction.
        item_id: ID, // The item being auctioned.
        seller: address, // Address of the seller of the item.
        starting_price: u64, // Starting price of the item in SUI tokens.
        end_time: u64, // Timestamp for the end time of the auction.
        reserve_price: u64, // Minimum price for which the item can be sold.
        highest_bidder: Option<address>, // The current highest bidder's address, if available.
        highest_bid: u64, // Current highest bid amount.
        bids: vector<BidInfo>, // Vector storing all the bids on the auction.
        pool: Balance<SUI>, // Pool of funds collected from the bids.
    }

    // Struct to represent a bid in an auction.
    public struct BidInfo has store, drop {
        bidder: address,
        amount: u64,
        is_claimed: bool,
    }

    // Events
    public struct AuctionCreated has copy, drop {
        auction_id: ID,
        item_id: ID,
    }

    public struct BidPlaced has copy, drop {
        auction_id: ID,
        bidder: address,
        amount: u64,
    }

    public struct AuctionEnded has copy, drop {
        auction_id: ID,
        winner: address,
        amount: u64,
    }

    public struct FundsWithdrawn has copy, drop {
        recipient: address,
        amount: u64,
    }

    // Functions for managing the rare items auction contract.

    // Initializes the auction house by creating an AuctionHouseCap object.
    fun init(ctx: &mut TxContext) {
        let auction_house = AuctionHouseCap {
            id: object::new(ctx), // Generate a new unique ID for the auction house.
            auctions: vector::empty<ID>(), // Initialize an empty list of auctions.
            wallet: zero<SUI>(), // Initialize the wallet with zero balance.
        };
        transfer::transfer(auction_house, tx_context::sender(ctx)); // Transfer ownership of the auction house to the caller.
    }

    // Add test-only initialization function
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    // Adds a new item to the auction contract.
    public entry fun add_item(
        name: String,
        item_type: String,
        description: String,
        metadata: String,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let item = Item {
            id: object::new(ctx),
            owner: sender,
            name,
            item_type,
            description,
            metadata,
        };
        // Transfer the item to the creator
        transfer::transfer(item, sender);
    }

    // Modified add_auction function
    public entry fun add_auction(
        auction_house: &mut AuctionHouseCap,
        item: &mut Item,
        starting_price: u64,
        end_times: u64,
        reserve_price: u64,
        c: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Verify item ownership
        assert!(item.owner == sender, EItemNotOwnedBySeller);

        let end_time = clock::timestamp_ms(c) + end_times;
        let item_id = object::uid_to_inner(&item.id);
        let auction_id = object::new(ctx);
        let auction_id_inner = object::uid_to_inner(&auction_id);

        let auction = Auction {
            id: auction_id,
            item_id,
            seller: sender,
            starting_price,
            end_time,
            reserve_price,
            highest_bidder: option::none(),
            highest_bid: 0,
            bids: vector::empty(),
            pool: balance::zero<SUI>(),
        };
        
        // Share the auction object
        transfer::share_object(auction);
        
        // Add auction ID to auction house
        vector::push_back(&mut auction_house.auctions, auction_id_inner);

        // Emit auction created event
        event::emit(AuctionCreated {
            auction_id: auction_id_inner,
            item_id,
        });
    }

    // Helper function to get item owner
    public fun get_item_owner(item: &Item): address {
        item.owner
    }

    // Allows a bidder to place a bid on an auction.
    public entry fun place_bid(
        auction: &mut Auction, // Reference to the auction being bid on.
        bidder: address, // Address of the bidder.
        amount: Coin<SUI>, // The bid amount in SUI tokens.
        clock: &Clock, // Reference to the clock for timing purposes.
    ) {
        assert!(auction.end_time > clock::timestamp_ms(clock), EEndTimeNotReached); // Ensure auction hasn't ended.

        let amount_u64 = coin::value(&amount); // Convert the bid amount to u64.
        let highest_bid = auction.highest_bid; // Get the current highest bid.

        // Ensure the bid is greater than the starting price
        assert!(amount_u64 >= auction.starting_price, EInvalidBid);

        assert!(amount_u64 > highest_bid, EInvalidBid); // Ensure the new bid is higher than the current highest bid.

        let bid = BidInfo {
            bidder,
            amount: amount_u64,
            is_claimed: false,
        };

        let bid_amount = coin::into_balance(amount); // Convert the bid amount to balance.
        balance::join(&mut auction.pool, bid_amount); // Add the bid amount to the auction pool.

        auction.highest_bid = amount_u64; // Update the highest bid.
        auction.highest_bidder = some(bidder); // Update the highest bidder.
        vector::push_back(&mut auction.bids, bid); // Add the bid to the list of bids.

        event::emit(BidPlaced {
            auction_id: uid_to_inner(&auction.id),
            bidder,
            amount: amount_u64,
        });
    }

    // Allows the seller to accept the highest bid and transfer the item to the highest bidder.
    public entry fun accept_bid(
        auction: &mut Auction,
        bid_index: u64,  // Index of the bid to accept
        item: &mut Item,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the item
        assert!(item.owner == tx_context::sender(ctx), ENotOwner);

        // Ensure the auction has ended
        assert!(auction.end_time < clock::timestamp_ms(clock), EEndTimeNotReached);

        // Retrieve the highest bidder
        let highest_bidder = if (option::is_some(&auction.highest_bidder)) {
            option::borrow(&auction.highest_bidder)
        } else {
            abort(ENoAuctions)
        };

        // Retrieve the bid
        let bid = vector::borrow_mut(&mut auction.bids, bid_index);
        assert!(bid.bidder == *highest_bidder, ENotBidder);
        assert!(!bid.is_claimed, EClaimedBid);

        // Transfer item ownership to the highest bidder
        item.owner = bid.bidder;
        bid.is_claimed = true;

        // Transfer the bid amount to the seller
        let bid_amount = coin::take(&mut auction.pool, auction.highest_bid, ctx);
        transfer::public_transfer(bid_amount, auction.seller);

        // Emit an event for the auction ending
        event::emit(AuctionEnded {
            auction_id: uid_to_inner(&auction.id),
            winner: bid.bidder,
            amount: auction.highest_bid,
        });
    }

    // Allows a bidder to withdraw their bid.
    public entry fun withdraw_bid(
        auction: &mut Auction, // Reference to the auction.
        bid_index: u64, // Index of the bid being withdrawn.
        ctx: &mut TxContext
    ) {
        let bid = vector::borrow_mut(&mut auction.bids, bid_index);
        assert!(bid.bidder == tx_context::sender(ctx), ENotBidder);
        assert!(!bid.is_claimed, EClaimedBid);

        bid.is_claimed = true;

        let bid_amount = coin::take(&mut auction.pool, bid.amount, ctx);
        transfer::public_transfer(bid_amount, bid.bidder);

        // Remove the bid from the vector
        vector::remove(&mut auction.bids, bid_index);
    }

    // Allows the seller to withdraw the funds from the auction pool.
    public entry fun withdraw_pool(
        auction: &mut Auction, // Reference to the auction.
        amount: u64, // Amount to withdraw.
        ctx: &mut TxContext
    ) {
        assert!(auction.seller == tx_context::sender(ctx), ENotOwner);
        assert!(balance::value(&auction.pool) >= amount, EInvalidWithdrawalAmount);

        let withdrawn = coin::take(&mut auction.pool, amount, ctx);
        transfer::public_transfer(withdrawn, auction.seller);

        event::emit(FundsWithdrawn {
            recipient: auction.seller,
            amount,
        });
    }

    // Access bids using indices
    public fun get_bid(auction: &Auction, index: u64): &BidInfo {
        vector::borrow(&auction.bids, index)
    }

    #[test_only]
    // call the init function
    public fun test_init(ctx: &mut TxContext) {
        init( ctx);
    }

}