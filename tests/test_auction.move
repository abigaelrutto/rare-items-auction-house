#[test_only]
module auction::test_voting {
    use sui::test_scenario::{Self as ts, next_tx, ctx};
    use sui::test_utils::{assert_eq};
    use sui::clock::{Clock, Self};
    use sui::sui::{SUI};

    use std::string::{Self};

    const ADMIN: address = @0xe;
    use auction::helpers::init_test_helper;
    use auction::rare_items_auction::{Self as ria, AuctionHouseCap, Item, Auction, Bid};

    #[test]
    public fun test() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;
        
        // lets create new item
        next_tx(scenario, ADMIN);
        {
            let owner = ADMIN;
            let name = string::utf8(b"asd");
            let item_type = string::utf8(b"asd");
            let description = string::utf8(b"asd");
            let metadata = string::utf8(b"asd");

            let item = ria::add_item(
            owner,
            name,
            item_type,
            description,
            metadata,
            ts::ctx(scenario)
            );
            transfer::public_transfer(item, ADMIN);
        };

        // lets create add_auction
        next_tx(scenario, ADMIN);
        {
            let mut cap = ts::take_from_sender<AuctionHouseCap>(scenario);
            let item = ts::take_from_sender<Item>(scenario);
            let c = clock::create_for_testing(ts::ctx(scenario));
            
            let owner = ADMIN;
            let name = string::utf8(b"asd");
            let item_type = string::utf8(b"asd");
            let description = string::utf8(b"asd");
            let metadata = string::utf8(b"asd");

            ria::add_auction(
            &mut cap,
            &item,
            ADMIN,
            1_000_000_000,
            100000,
            1_000_000_000,
            &c,
            ts::ctx(scenario)
            );
            clock::share_for_testing(c);
            ts::return_to_sender(scenario, cap);
            ts::return_to_sender(scenario, item);
        };

        ts::end(scenario_test);
    }
}
