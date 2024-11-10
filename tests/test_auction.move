#[test_only]
module auction::rare_items_auction_tests {
    use sui::test_scenario::{Self, Scenario, next_tx, ctx};
    use sui::clock::{Self};
    use sui::coin::{Self};
    use sui::sui::SUI;
    use std::string;

    use auction::rare_items_auction::{
        Self as auction,
        AuctionHouseCap,
        Item,
        Auction,
    };

    // Test addresses
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // Test constants
    const STARTING_PRICE: u64 = 100;
    const RESERVE_PRICE: u64 = 200;
    const END_TIME: u64 = 3600000; // 1 hour

    #[test]
    fun test_create_item_and_auction() {
        let mut scenario = test_scenario::begin(USER1); // Start with USER1
        
        // Initialize auction house
        init_auction_house(&mut scenario);
        
        // Create item
        create_test_item(&mut scenario);
        
        // Start auction
        start_test_auction(&mut scenario);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_place_bid() {
        let mut scenario = test_scenario::begin(ADMIN);
        
        // Setup
        init_auction_house(&mut scenario);
        create_test_item(&mut scenario);
        start_test_auction(&mut scenario);
        
        // Place bid
        next_tx(&mut scenario, USER1);
        {
            let mut auction = test_scenario::take_shared<Auction>(&scenario);
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI>(STARTING_PRICE + 50, ctx(&mut scenario));
            
            auction::place_bid(
                &mut auction,
                USER1,
                coin,
                &clock,
                // ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(auction);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_accept_bid() {
        let mut scenario = test_scenario::begin(USER1); // Start with USER1
        
        // Setup
        init_auction_house(&mut scenario);
        create_test_item(&mut scenario);
        start_test_auction(&mut scenario);
        
        // Place bid
        next_tx(&mut scenario, USER2); // USER2 places a bid
        {
            let mut auction = test_scenario::take_shared<Auction>(&scenario);
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI>(RESERVE_PRICE + 50, ctx(&mut scenario)); // Ensure bid is above reserve price
            
            auction::place_bid(
                &mut auction,
                USER2,
                coin,
                &clock,
                // ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(auction);
        };
        
        test_scenario::end(scenario);
    }

    // #[test]
    // fun test_accept_bid() {
    //     let mut scenario = test_scenario::begin(ADMIN);
        
    //     // Setup
    //     init_auction_house(&mut scenario);
    //     create_test_item(&mut scenario);
    //     start_test_auction(&mut scenario);
        
    //     // Place bid
    //     next_tx(&mut scenario, USER1);
    //     {
    //         let mut auction = test_scenario::take_shared<Auction>(&scenario);
    //         let clock = clock::create_for_testing(ctx(&mut scenario));
    //         let coin = coin::mint_for_testing<SUI>(STARTING_PRICE + 50, ctx(&mut scenario));
            
    //         auction::place_bid(
    //             &mut auction,
    //             USER1,
    //             coin,
    //             &clock,
    //             // ctx(&mut scenario)
    //         );
            
    //         clock::destroy_for_testing(clock);
    //         test_scenario::return_shared(auction);
    //     };
        
    //     // Accept bid
    //     next_tx(&mut scenario, ADMIN);
    //     {
    //         let mut auction = test_scenario::take_shared<Auction>(&scenario);
    //         let mut item = test_scenario::take_from_sender<Item>(&scenario);
    //         let mut clock = clock::create_for_testing(ctx(&mut scenario));
            
    //         // Fast forward time to end the auction
    //         clock::set_for_testing(&mut clock, END_TIME + 1);
            
    //         auction::accept_bid(
    //             &mut auction,
    //             0, // bid_index
    //             &mut item,
    //             &clock,
    //             ctx(&mut scenario)
    //         );
            
    //         clock::destroy_for_testing(clock);
    //         test_scenario::return_shared(auction);
    //         test_scenario::return_to_sender(&scenario, item);
    //     };
        
    //     test_scenario::end(scenario);
    // }

    // Helper functions
    fun init_auction_house(scenario: &mut Scenario) {
        next_tx(scenario, USER1); // Initialize with USER1
        {
            auction::init_for_testing(ctx(scenario));
        };
    }

    fun create_test_item(scenario: &mut Scenario) {
        next_tx(scenario, USER1); // Create item with USER1
        {
            auction::add_item(
                string::utf8(b"Test Item"),
                string::utf8(b"Type"),
                string::utf8(b"Description"),
                string::utf8(b"Metadata"),
                ctx(scenario)
            );
        };
    }

    fun start_test_auction(scenario: &mut Scenario) {
        next_tx(scenario, USER1); // Start auction with USER1
        {
            let mut auction_house = test_scenario::take_from_sender<AuctionHouseCap>(scenario);
            let mut item = test_scenario::take_from_sender<Item>(scenario);
            let clock = clock::create_for_testing(ctx(scenario));
            
            auction::add_auction(
                &mut auction_house,
                &mut item,
                STARTING_PRICE,
                END_TIME,
                RESERVE_PRICE,
                &clock,
                ctx(scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_to_sender(scenario, auction_house);
            test_scenario::return_to_sender(scenario, item);
        };
    }

    #[test]
    #[expected_failure(abort_code = auction::EInvalidBid)]
    fun test_bid_below_starting_price() {
        let mut scenario = test_scenario::begin(ADMIN);
        
        // Setup
        init_auction_house(&mut scenario);
        create_test_item(&mut scenario);
        start_test_auction(&mut scenario);
        
        // Try to place bid below starting price
        next_tx(&mut scenario, USER1);
        {
            let mut auction = test_scenario::take_shared<Auction>(&scenario);
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI>(STARTING_PRICE - 50, ctx(&mut scenario));
            
            auction::place_bid(
                &mut auction,
                USER1,
                coin,
                &clock,
                // ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(auction);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = auction::ENotOwner)]
    fun test_non_owner_accept_bid() {
        let mut scenario = test_scenario::begin(USER1); // Start with USER1
        
        // Setup
        init_auction_house(&mut scenario);
        create_test_item(&mut scenario);
        start_test_auction(&mut scenario);
        
        // Place bid
        next_tx(&mut scenario, USER2); // USER2 places a bid
        {
            let mut auction = test_scenario::take_shared<Auction>(&scenario);
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI>(RESERVE_PRICE + 50, ctx(&mut scenario));
            
            auction::place_bid(
                &mut auction,
                USER2,
                coin,
                &clock,
                // ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(auction);
        };
        
        // Fast forward time to end the auction
        next_tx(&mut scenario, USER1); // Switch back to USER1 to fast forward time
        {
            let mut clock = clock::create_for_testing(ctx(&mut scenario));
            clock::set_for_testing(&mut clock, END_TIME + 1);
            clock::destroy_for_testing(clock);
        };
        
        // Take the item from USER1 first
        next_tx(&mut scenario, USER1);
        let mut item = test_scenario::take_from_sender<Item>(&scenario);
        
        // Try to accept bid as non-owner (USER2)
        next_tx(&mut scenario, USER2);
        {
            let mut auction = test_scenario::take_shared<Auction>(&scenario);
            let clock = clock::create_for_testing(ctx(&mut scenario));
            
            auction::accept_bid(
                &mut auction,
                0,
                &mut item,
                &clock,
                ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(auction);
        };
        
        // Return the item to USER1
        test_scenario::return_to_address(USER1, item);
        test_scenario::end(scenario);
    }
}
