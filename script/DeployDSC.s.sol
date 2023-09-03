// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    DecentralizedStableCoin decentralizedStableCoin;
    DSCEngine dscEngine;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address ethPriceFeed, address btcPriceFeed, address eth, address btc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [eth, btc];
        priceFeedAddresses = [ethPriceFeed, btcPriceFeed];
        vm.startBroadcast(deployerKey);
        decentralizedStableCoin = new DecentralizedStableCoin();
        dscEngine = new DSCEngine(tokenAddresses,priceFeedAddresses,address(decentralizedStableCoin));
        decentralizedStableCoin.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (decentralizedStableCoin, dscEngine, helperConfig);
    }
}
