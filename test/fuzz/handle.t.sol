// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;
import {Test} from "forge-std/Test.sol";
import {eNRS} from "../../src/eNRS/eNRS.sol";
import {eNRS_Engine} from "../../src/eNRS/eNRS_Engine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test{

    eNRS enrs;
    eNRS_Engine engine;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE =type(uint128).max;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;


    constructor(eNRS _enrs, eNRS_Engine _engine){
        enrs =_enrs;
        engine =_engine;
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

    }

    function minteNRS(uint256 amount, uint256 senderSeed)public{
        // amount = bound(amount,1,MAX_DEPOSIT_SIZE);
        // vm.assume(usersWithCollateralDeposited.length!=0);
                timesMintIsCalled++;

        if(usersWithCollateralDeposited.length ==0){
            return;
        }
        address sender = usersWithCollateralDeposited[senderSeed %usersWithCollateralDeposited.length];
        (uint256 totaleNRSMinted, uint256 collateralValueInUSD)=engine.getAccountInfo(sender);
        int256 maxAmountToMint = (int256(collateralValueInUSD)/2)-int256(totaleNRSMinted);
        if(maxAmountToMint<0){
            return;
        }
        amount = bound(amount,0,uint256(maxAmountToMint));
        if(amount==0){
            return;
        }
        vm.startPrank(sender);

        engine.minteNRS(amount);
        vm.stopPrank();
    }





    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        amountCollateral =bound(amountCollateral,1,MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender,amountCollateral);
        collateral.approve(address(engine),amountCollateral);


        engine.depositCollateral(address(collateral),amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed,uint256 amountCollateral) public{
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalance(msg.sender,address(collateral));
        //  vm.assume(amountCollateral!=0);
    
        amountCollateral = bound(amountCollateral,0,maxCollateralToRedeem);
             if (amountCollateral ==0){
            return;
        }
       
        engine.redeemCollateral(address(collateral),amountCollateral);
    }


    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
        if(collateralSeed%2 == 0)return weth;
        return wbtc;
    }

}
