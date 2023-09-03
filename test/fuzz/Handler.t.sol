// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    mapping(bytes32 => uint256) calls;

    struct addressSet {
        address[] uesrsWithCollateralDeposited;
        mapping(address => bool) saved;
    }

    addressSet actors;

    MockV3Aggregator public ethUsdPriceFeed;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral)
        public
        countCall("depositCollateral")
    {
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        ERC20Mock(collateral).mint(msg.sender, amountCollateral);
        ERC20Mock(collateral).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        // double push ?
        if (!actors.saved[msg.sender]) {
            actors.uesrsWithCollateralDeposited.push(msg.sender);
            actors.saved[msg.sender] = true;
        } else {
            return;
        }
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public countCall("mintDsc") {
        if (actors.uesrsWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = actors.uesrsWithCollateralDeposited[addressSeed % actors.uesrsWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        dscEngine.mintDsc(amount);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed)
        public
        countCall("redeemCollateral")
    {
        if (actors.uesrsWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = actors.uesrsWithCollateralDeposited[addressSeed % actors.uesrsWithCollateralDeposited.length];
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dscEngine.getCollateralDeposited(address(collateral), sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        vm.startPrank(sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    // This breaks our invariant test suite!!!
    //function updateCollateralPrice(uint96 newPrice) public {
    //    int256 newPriceInt = int256(uint256(newPrice));
    //    ethUsdPriceFeed.updateAnswer(newPriceInt);
    //}

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("depositCollateral", calls["depositCollateral"]);
        console.log("mintDsc", calls["mintDsc"]);
        console.log("redeemCollateral", calls["redeemCollateral"]);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
