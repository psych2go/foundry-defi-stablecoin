// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );

    DeployDSC deployer;
    HelperConfig helperConfig;
    DecentralizedStableCoin decentralizedStableCoin;
    DSCEngine dscEngine;

    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;
    uint256 public constant MINT_DSC_AMOUNT = 2 ether;
    uint256 public constant BURN_DSC_AMOUNT = 1 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (decentralizedStableCoin, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE);
    }

    ////////////////////////
    // Constructor Tests  //
    ////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address[] public DSCEngine_tokens;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine_TokenAddressesAndPriceFeedAddressedMustBeSameLength.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses,address(decentralizedStableCoin));
    }

    function testConstructorConfig() public {
        assert(dscEngine.getPriceFeeds(weth) == wethUsdPriceFeed);
        assert(dscEngine.getPriceFeeds(wbtc) == wbtcUsdPriceFeed);
        DSCEngine_tokens = dscEngine.getCollateralTokens();
        assert(DSCEngine_tokens[0] == weth);
        assert(DSCEngine_tokens[1] == wbtc);
    }
    /////////////////
    // Price Tests //
    /////////////////

    function testGetUsdValue() public view {
        assert(dscEngine.getUsdValue(weth, 1e18) == 2000 * 1e18);
        assert(dscEngine.getUsdValue(wbtc, 3e18) == 90000 * 1e18);
    }

    function testGetTokenAmountFromUsd() public view {
        assert(dscEngine.getTokenAmountFromUsd(weth, 2000 * 1e18) == 1e18);
        assert(dscEngine.getTokenAmountFromUsd(wbtc, 90000 * 1e18) == 3e18);
    }

    //////////////////////////////
    // depositCollateral Tests  //
    //////////////////////////////
    function testRevertsIfCollateralZero() public {
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock erc20 = new ERC20Mock();
        vm.expectRevert(DSCEngine.DSCEngine_NotAllowedToken.selector);
        dscEngine.depositCollateral(address(erc20), 1 ether);
    }

    function testCanDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, false, true, address(dscEngine));
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        assert(dscEngine.getCollateralDeposited(USER, weth) == AMOUNT_COLLATERAL);
        assert(ERC20Mock(weth).balanceOf(address(dscEngine)) == AMOUNT_COLLATERAL);
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assert(totalDscMinted == 0);
        assert(dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd) == AMOUNT_COLLATERAL);
    }

    function testMintDSC() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.mintDsc(MINT_DSC_AMOUNT);
        vm.stopPrank();
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);
        assert(totalDscMinted == MINT_DSC_AMOUNT);
    }

    modifier mintDSC() {
        vm.startPrank(USER);
        dscEngine.mintDsc(MINT_DSC_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testRedeemCollateral() public depositCollateral depositCollateral mintDSC {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, true, address(dscEngine));
        emit CollateralRedeemed(USER, USER, weth, AMOUNT_COLLATERAL);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        (, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assert(dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd) == AMOUNT_COLLATERAL);
        assert(dscEngine.getCollateralDeposited(USER, weth) == AMOUNT_COLLATERAL);
        assert(ERC20Mock(weth).balanceOf(address(dscEngine)) == AMOUNT_COLLATERAL);
    }

    function testBurnDSC() public depositCollateral depositCollateral mintDSC {
        vm.startPrank(USER);
        decentralizedStableCoin.approve(address(dscEngine), BURN_DSC_AMOUNT);
        dscEngine.burnDsc(BURN_DSC_AMOUNT);
        vm.stopPrank();
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);
        assert(totalDscMinted == MINT_DSC_AMOUNT - BURN_DSC_AMOUNT);
    }

    function testDepositCollateralAndMintDSC() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, MINT_DSC_AMOUNT);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assert(totalDscMinted == MINT_DSC_AMOUNT);
        assert(dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd) == AMOUNT_COLLATERAL);
    }

    function testRedeemCollateralAndBurnDSC() public depositCollateral depositCollateral mintDSC {
        vm.startPrank(USER);
        decentralizedStableCoin.approve(address(dscEngine), BURN_DSC_AMOUNT);
        dscEngine.redeemCollateralAndBurnDSC(weth, AMOUNT_COLLATERAL, BURN_DSC_AMOUNT);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assert(totalDscMinted == MINT_DSC_AMOUNT - BURN_DSC_AMOUNT);
        assert(dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd) == AMOUNT_COLLATERAL);
    }
}
