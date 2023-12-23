// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {eNRS} from "../src/eNRS/eNRS.sol";
import {eNRS_Engine} from "../src/eNRS/eNRS_Engine.sol";
import { HelperConfig} from "./HelperConfig.s.sol";

contract DeployeNRS is Script{

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (eNRS, eNRS_Engine,HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        (address wethPriceFeed, address wbtcPriceFeed, address weth, address wbtc, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        tokenAddresses = [weth,wbtc];
        priceFeedAddresses = [wethPriceFeed,wbtcPriceFeed];
        vm.startBroadcast(deployerKey);
        eNRS enrs = new eNRS();
        eNRS_Engine engine = new eNRS_Engine(tokenAddresses,priceFeedAddresses,address(enrs));
        
        enrs.transferOwnership(address(engine));
        vm.stopBroadcast();
        return(enrs,engine,helperConfig);
    }
    
}