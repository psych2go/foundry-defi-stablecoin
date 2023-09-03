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

contract OpenInvariantsTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;

    address public weth;
    address public wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        targetContract(address(dscEngine));
    }

    function invariant_stateless_protocolMustHaveMoreValueThanTotalSupply() public {
        uint256 wethAmount = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 wbtcAmount = ERC20Mock(wbtc).balanceOf(address(dscEngine));
        uint256 dscUsdValue = dsc.totalSupply(); // pegged $1
        uint256 wethUsdValue = dscEngine.getUsdValue(weth, wethAmount);
        uint256 wbtcUsdValue = dscEngine.getUsdValue(wbtc, wbtcAmount);
        assertGe(wethUsdValue + wbtcUsdValue, dscUsdValue);
    }
}
