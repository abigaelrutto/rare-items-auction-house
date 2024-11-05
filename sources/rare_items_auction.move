// Decentralized Rare Items Auction House
module auction::rare_items_auction {
    // This module defines the rare items auction contract.

    // Importing necessary modules from the standard library and SUI.
    use sui::sui::SUI;
    use sui::coin::{Self, Coin}; // Manages coins and balances in the SUI blockchain.
    use sui::balance::{Self, Balance}; // Handles balance operations.
    use std::string::String; // Importing string utilities.
    use sui::clock::{Self, Clock}; // For managing time-based operations (like auction timing).
    use std::option::{none, some}; // Optional values to handle cases like the highest bid being absent.

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
        item_id: UID, // The item being auctioned.
        seller: address, // Address of the seller of the item.
        starting_price: u64, // Starting price of the item in SUI tokens.
        end_time: u64, // Timestamp for the end time of the auction.
        reserve_price: u64, // Minimum price for which the item can be sold.
        highest_bidder: Option<address>, // The current highest bidder's address, if available.
        highest_bid: u64, // Current highest bid amount.
        bids: vector<Bid>, // Vector storing all the bids on the auction.
        pool: Balance<SUI>, // Pool of funds collected from the bids.
    }

    // Struct to represent a bid in an auction.
    public struct Bid has key, store {
        id: UID, // Unique identifier for the bid.
        bidder: address, // Address of the bidder.
        amount: u64, // The amount bid in SUI tokens.
        is_claimed: bool, // Boolean to indicate if the bid escrow is claimed.
    }

    // Error codes used in the rare items auction contract.
    const EEndTimeNotReached: u64 = 0; // Error when attempting an operation before the auction ends.
    const ENotBidder: u64 = 2; // Error for unauthorized bidder operations.
    const EInsufficientBid: u64 = 5; // Error for insufficient bid amount.
    const EInvalidBid: u64 = 6; // Error for placing a bid that is lower than the highest bid.
    const EClaimedBid: u64 = 7; // Error when trying to withdraw an already claimed bid.
    const ENoAuctions: u64 = 8; // Error when there are no auctions available.

    // Functions for managing the rare items auction contract.

    // Initializes the auction house by creating an AuctionHouseCap object.
    fun init(ctx: &mut TxContext) {
        let auction_house = AuctionHouseCap {
            id: object::new(ctx), // Generate a new unique ID for the auction house.
            auctions: vector::empty<ID>(), // Initialize an empty list of auctions.
            wallet: balance::zero<SUI>(), // Initialize the wallet with zero balance.
        };
        transfer::transfer(auction_house, tx_context::sender(ctx)); // Transfer ownership of the auction house to the caller.
    }

    // Adds a new item to the auction contract.
    public fun add_item(
        owner: address, // Address of the item owner.
        name: String, // Name of the item.
        item_type: String, // Type/category of the item.
        description: String, // Description of the item.
        metadata: String, // Additional metadata related to the item.
        ctx: &mut TxContext
    ) : Item {
        let id = object::new(ctx); // Generate a unique ID for the item.
        Item {
            id, // Unique item ID.
            owner, // Owner address.
            name, // Item name.
            item_type, // Type of the item.
            description, // Item description.
            metadata, // Metadata about the item.
        }
    }

    // Adds a new auction to the auction house.
    public fun add_auction(
        auction_house: &mut AuctionHouseCap, // Reference to the auction house.
        item: &Item, // Reference to the item being auctioned.
        seller: address, // Address of the seller.
        item_id: UID, // Unique ID of the item being auctioned.
        starting_price: u64, // The starting price of the item.
        end_time: u64, // Auction end time in milliseconds.
        reserve_price: u64, // Reserve price, the minimum acceptable bid.
        ctx: &mut TxContext
    ) {
        // Verify that the caller is the owner of the item.
        assert!(item.owner == tx_context::sender(ctx), ENotBidder);

        let id = object::new(ctx); // Create a unique ID for the auction.
        let inner = object::uid_to_inner(&id); // Convert the auction ID to its inner representation.
        let auction = Auction {
            id, // Unique auction ID.
            item_id, // The item being auctioned.
            seller, // Seller's address.
            starting_price, // Starting price for the auction.
            end_time, // Auction's end time.
            reserve_price, // Reserve price for the auction.
            highest_bidder: none(), // No highest bidder initially.
            highest_bid: 0, // Highest bid starts at zero.
            bids: vector::empty(), // Initialize an empty list of bids.
            pool: balance::zero<SUI>(), // Initialize the auction pool with zero balance.
        };
        transfer::share_object(auction); // Share the auction object.
        vector::push_back(&mut auction_house.auctions, inner); // Add the auction to the auction house's list of auctions.
    }

    // Allows a bidder to place a bid on an auction.
    public fun place_bid(
        auction: &mut Auction, // Reference to the auction being bid on.
        bidder: address, // Address of the bidder.
        amount: Coin<SUI>, // The bid amount in SUI tokens.
        clock: &Clock, // Reference to the clock for timing purposes.
        ctx: &mut TxContext
    ) {
        assert!(auction.end_time > clock::timestamp_ms(clock), EEndTimeNotReached); // Ensure auction hasn't ended.

        let amount_u64 = coin::value(&amount); // Convert the bid amount to u64.
        let highest_bid = auction.highest_bid; // Get the current highest bid.

        assert!(amount_u64 > highest_bid, EInvalidBid); // Ensure the new bid is higher than the current highest bid.

        let id = object::new(ctx); // Create a unique ID for the bid.
        let bid = Bid {
            id, // Unique bid ID.
            bidder, // Bidder's address.
            amount: amount_u64, // Bid amount.
            is_claimed: false, // Bid is not claimed yet.
        };

        let bid_amount = coin::into_balance(amount); // Convert the bid amount to balance.
        balance::join(&mut auction.pool, bid_amount); // Add the bid amount to the auction pool.

        auction.highest_bid = amount_u64; // Update the highest bid.
        auction.highest_bidder = some(bidder); // Update the highest bidder.
        auction.bids.push_back(bid); // Add the bid to the list of bids.
    }

    // Allows the seller to accept the highest bid and transfer the item to the highest bidder.
    public fun accept_bid(
        auction: &mut Auction, // Reference to the auction.
        bid: &mut Bid, // Reference to the bid being accepted.
        item: &mut Item, // Reference to the item being auctioned.
        clock: &Clock, // Reference to the clock for timing purposes.
        ctx: &mut TxContext
    ) {
        assert!(auction.end_time < clock::timestamp_ms(clock), EEndTimeNotReached); // Ensure the auction has ended.
        assert!(auction.highest_bid >= auction.reserve_price, EInsufficientBid); // Ensure the highest bid meets the reserve price.

        // Get the highest bidder's address.
        let highest_bidder = if (option::is_some(&auction.highest_bidder)) {
            option::borrow(&auction.highest_bidder)
        } else {
            abort(ENoAuctions) // Abort if no highest bidder is found.
        };
        assert!(bid.bidder == highest_bidder, ENotBidder); // Ensure the bid belongs to the highest bidder.

        let highest_bid = auction.highest_bid; // Get the highest bid amount.

        // Transfer the item to the highest bidder.
        item.owner = bid.bidder;
        bid.is_claimed = true; // Markthe bid as claimed.

        let bid_amount = coin::take(&mut auction.pool, highest_bid, ctx); // Withdraw the bid amount from the auction pool.
        transfer::public_transfer(bid_amount, auction.seller); // Transfer the funds to the seller.
    }

    // Allows a bidder to withdraw their bid.
    public fun withdraw_bid(
        auction: &mut Auction, // Reference to the auction.
        bid: &mut Bid, // Reference to the bid being withdrawn.
        ctx: &mut TxContext
    ) {
        assert!(bid.bidder == tx_context::sender(ctx), ENotBidder); // Ensure the caller is the bidder.
        assert!(!bid.is_claimed, EClaimedBid); // Ensure the bid hasn't been claimed yet.

        bid.is_claimed = true; // Mark the bid as claimed.

        let bid_amount = coin::take(&mut auction.pool, bid.amount, ctx); // Withdraw the bid amount from the auction pool.
        transfer::public_transfer(bid_amount, bid.bidder); // Transfer the funds back to the bidder.
    }

    // Allows the seller to withdraw the funds from the auction pool.
    public fun withdraw_pool(
        auction: &mut Auction, // Reference to the auction.
        amount: u64, // Amount to withdraw.
        ctx: &mut TxContext
    ) {
        assert!(auction.seller == tx_context::sender(ctx), ENotBidder); // Ensure the caller is the seller.
        assert!(balance::value(&auction.pool) >= amount, EInsufficientBid); // Ensure sufficient funds in the auction pool.

        let withdrawn = coin::take(&mut auction.pool, amount, ctx); // Withdraw the specified amount from the pool.
        transfer::public_transfer(withdrawn, auction.seller); // Transfer the funds to the seller.
    }        
}
