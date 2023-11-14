// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;
import {Test} from "forge-std/Test.sol";
import {DeployeNRS} from "../../script/DeployeNRS.s.sol";
import {eNRS} from "../../src/eNRS.sol";
import {eNRS_Engine} from "../../src/eNRS_Engine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract eNRSTest is Test{

    // DeployeNRS deployer;
    eNRS public enrs;
    eNRS_Engine public engine;
    HelperConfig public helper;

    address ethUSDPriceFeed;
    address btcUSDPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public{
        DeployeNRS deployer = new DeployeNRS();
        (enrs,engine,helper) = deployer.run();
        (ethUSDPriceFeed,btcUSDPriceFeed,weth,,) = helper.activeNetworkConfig();

        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
        

    }

    // Modifier

    modifier depositedCollateralAndMinted{
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),AMOUNT_COLLATERAL);
        engine.depositCollateralAndMinteNRS(weth,AMOUNT_COLLATERAL,100);

        vm.stopPrank();

        _;
    } 


    // Constructor Test

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function test_revertsIfTokenLengthDOesntMatchPriceFeeds()public{
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUSDPriceFeed);
        priceFeedAddresses.push(btcUSDPriceFeed);

        vm.expectRevert(eNRS_Engine.eNRS_Engine_TokenAddressesAndPriceFeedAddressesMismatch.selector);
        new eNRS_Engine(tokenAddresses,priceFeedAddresses,address(enrs));
    }



    // pRICE TESTs


    function test_getUSDValue( ) public {
    uint256 ethAmount = 15e18;
    uint256  expectedUSD = 30000e18;
    uint256 actualUSD = engine.getUSDValue(weth, ethAmount);
    assertEq(expectedUSD,actualUSD);


    }

    function test_getTokenAmountFromUSD()public{
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromUsd(weth,usdAmount);
        assertEq(expectedWeth,actualWeth);
    }


    ////// Deposit COllateral Test//////

    function test_RevertsIfCOllateralZero() public{
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),AMOUNT_COLLATERAL);

        vm.expectRevert(eNRS_Engine.eNRS_Engine_NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }


    // HealthFactor Test

    // function test_HealthFactor () public depositedCollateralAndMinted{
    //     // uint256 healthfactor = 

    // }




}