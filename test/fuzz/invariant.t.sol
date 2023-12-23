// Invariants???
/**
 1. Total supply of eNRS should always be lessthan collateral

 */

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployeNRS} from "../../script/DeployeNRS.s.sol";
import {eNRS} from "../../src/eNRS/eNRS.sol";
import {eNRS_Engine} from "../../src/eNRS/eNRS_Engine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./handle.t.sol";

contract invariantTest is StdInvariant{
    DeployeNRS deployer;
    eNRS_Engine engine;
    eNRS enrs;
    HelperConfig helper;
    Handler handler;

    address weth;
    address wbtc;

    function setUp() external{
        deployer = new DeployeNRS();
        (enrs,engine,helper) = deployer.run();

        (,,weth,wbtc,) = helper.activeNetworkConfig();

        handler = new Handler(enrs,engine);
        targetContract(address(handler));

        // targetContract(address(engine));
    }

    function invariant_MustHaveMoreValueThanTotalCoinSupply() public view {

        uint256 totalSupply = enrs.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getNRSValue(weth,totalWethDeposited);
        uint256 wbtcValue = engine.getNRSValue(wbtc,totalWbtcDeposited);
        
        console.log("wethValue: ",wethValue);
        console.log("wbtcValue: ",wbtcValue);
        console.log("TotalSupply: ",totalSupply);
        console.log("Times mint called",handler.timesMintIsCalled());

        assert(wethValue+wbtcValue >= totalSupply);


    }


}
