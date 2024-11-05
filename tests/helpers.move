#[test_only]
module auction::helpers {
    use sui::test_scenario::{Self as ts};

    const ADMIN: address = @0xe;

    public fun init_test_helper() : ts::Scenario{

       let  scenario_val = ts::begin(ADMIN);
       scenario_val
    }

}