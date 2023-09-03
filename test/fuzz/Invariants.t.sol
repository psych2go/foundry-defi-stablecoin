// Have our invariant aka properties

// What are our invariants?

// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    Handler handler;

    address public weth;
    address public wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        handler = new Handler(dscEngine,dsc);
        targetContract(address(handler));
    }

    function invariant_statefull_protocolMustHaveMoreValueThanTotalSupply() public {
        uint256 wethAmount = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 wbtcAmount = ERC20Mock(wbtc).balanceOf(address(dscEngine));
        uint256 dscUsdValue = dsc.totalSupply(); // pegged $1
        uint256 wethUsdValue = dscEngine.getUsdValue(weth, wethAmount);
        uint256 wbtcUsdValue = dscEngine.getUsdValue(wbtc, wbtcAmount);

        console.log("weth value:", wethUsdValue);
        console.log("wbtc value:", wbtcUsdValue);
        console.log("dsc value:", dscUsdValue);

        assertGe(wethUsdValue + wbtcUsdValue, dscUsdValue);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
