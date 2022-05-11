// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./DssProxyActionsRebalance.sol";

contract DssProxyActionsRebalanceTest is DSTest {
    DssProxyActionsRebalance rebalance;

    function setUp() public {
        rebalance = new DssProxyActionsRebalance();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
