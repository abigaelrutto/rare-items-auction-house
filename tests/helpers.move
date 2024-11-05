#[test_only]
module auction::helpers {
    use sui::test_scenario::{Self as ts};

    const ADMIN: address = @0xe;

    use auction::rare_items_auction::test_init;

    public fun init_test_helper() : ts::Scenario {
        
       let mut scenario_val = ts::begin(ADMIN);
       let scenario = &mut scenario_val;
        
       test_init(ts::ctx(scenario));
       scenario_val
    }

}