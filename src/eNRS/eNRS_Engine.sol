// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {eNRS} from "./eNRS.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title Minimal stablecoin with the value of 1NRS == around 133.5 $
 * @author  sandman
 * @notice  COre of the eNRS contract
 */

contract eNRS_Engine is ReentrancyGuard {
    // ERRORS
    error eNRS_Engine_NeedsMoreThanZero();
    error eNRS_Engine_TokenAddressesAndPriceFeedAddressesMismatch();
    error eNRS_Engine_Token_NOT_ALLOWED();
    error eNRS_Engine_TransferFailed();
    error eNRS_Engine_BreaksHealthFactor(uint256);
    error eNRS_Engine_MintFailed();
    error eNRS_Engine_HealthFactorOKAY();
    error eNRS_Engine_HealthFactorNotImproved();

    // Events

    event CollateralDeposited(address, address, uint256);
    event CollateralRedeemed(address indexed redeemedFrom,address indexed RedeemedTo , address indexed token,uint256 amount );
    // State Variables/////////////////////////////

    eNRS private immutable enrs;

    address[] private s_CollateralTokens;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% OVERCOLLATERALIZED
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS=10;//10% BONUS
    uint256 private constant LIQUIDATION_PRECISION = 100;

    mapping(address token => address priceFeeds) private s_PriceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amounteNRSMinted) private s_eNRSMinted;

    // Modifires///////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert eNRS_Engine_NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_PriceFeeds[_token] == address(0)) revert eNRS_Engine_Token_NOT_ALLOWED();
        _;
    }

    //////////////////  Functions//////////////////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeeds, address eNRSAddress) {
        if (tokenAddresses.length != priceFeeds.length) {
            revert eNRS_Engine_TokenAddressesAndPriceFeedAddressesMismatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; ++i) {
            s_PriceFeeds[tokenAddresses[i]] = priceFeeds[i];
            s_CollateralTokens.push(tokenAddresses[i]);
        }
        enrs = eNRS(eNRSAddress);
    }

        /**
         * 
         * @param tokenCollateralAddress  address to deposit
         * @param amountCollateral Amount of collateral
         * @param amounteNRStoMint  Total stablecoin to deposit
         */
    function depositCollateralAndMinteNRS(address tokenCollateralAddress,uint256 amountCollateral, uint256 amounteNRStoMint) external {
        depositCollateral(tokenCollateralAddress,amountCollateral);
        minteNRS(amounteNRStoMint);

    }

    // External Functions////////////////////////////////

    /**
     *
     * @param tokenCollateralAddress Address of token to deposit as collateral
     * @param amountCollateral  amount to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert eNRS_Engine_TransferFailed();
        }
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant {
        
        _redeemCollateral(tokenCollateralAddress,amountCollateral,msg.sender,msg.sender);
    
        _revertIfHealthFactorIsBroken(msg.sender);


    }

    function redeemCollateralForeNRS(address tokenCollateralAddress, uint256 amountCollateral, uint256 amounteNRStoBurn) external {
        burneNRS(amounteNRStoBurn);
        redeemCollateral(tokenCollateralAddress,amountCollateral);
        // Already checcks health factor


    }

    /**
     *
     * @param _amountToMint  The amount of eNRS to mint
     * @notice They must have aminimum   collateral value to mint
     */
    function minteNRS(uint256 _amountToMint) public moreThanZero(_amountToMint) nonReentrant returns (bool) {
        s_eNRSMinted[msg.sender] += _amountToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = enrs.mint(msg.sender,_amountToMint);
        if(!minted){
            revert eNRS_Engine_MintFailed();
        }
        return minted;
    }

    function burneNRS(uint256 amount) public moreThanZero(amount){
     _burneNRS(amount,msg.sender,msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

/**
 * 
 * @param collateralAddress  ERC20 collat to liquidate from the user
 * @param user  User whose health factor is broken
 * @param debtToCover  Amount of eNRS to burn to improve the users health
 * 
 * @notice Can partially liquidate user
 * @notice Can get liqidatation bonus
 * @notice Assumes protocol will be roughly 200% overcollateralized
 */

    function liquidate(address collateralAddress, address user, uint256 debtToCover) external moreThanZero(debtToCover)nonReentrant{
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor>=MIN_HEALTH_FACTOR){
            revert eNRS_Engine_HealthFactorOKAY();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralAddress,debtToCover);

        uint256 bonusCollateral =(tokenAmountFromDebtCovered* LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;
        uint256 totalCollateralToReedem = tokenAmountFromDebtCovered +bonusCollateral;

        _redeemCollateral(collateralAddress,totalCollateralToReedem,user,msg.sender);

        // To Burn

        _burneNRS(debtToCover,user,msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);

        if(endingUserHealthFactor<=startingUserHealthFactor){
            revert eNRS_Engine_HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);

    }
    function getHealthFactor() external view {}

    // Internal Functions

    /**
     * @dev Donot call unless checking for healthfactor
     */

    function _burneNRS(uint256 amountToBurn,address onBehalf, address eNRSFrom ) private {

          s_eNRSMinted[onBehalf] -= amountToBurn;
        bool success = enrs.transferFrom(eNRSFrom,address(this),amountToBurn);
        if(!success){
            revert eNRS_Engine_TransferFailed();
        }
        enrs.burn(amountToBurn);
        // 

    }


    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral,address from, address to) private{
            s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from,to,tokenCollateralAddress,amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender,amountCollateral);
        if(!success){
            revert eNRS_Engine_TransferFailed();
        }

    }

    function _healthFactor(address user) private view returns (uint256) {
        // To get Collateral Value

        
        (uint256 totaleNRSMinted, uint256 collateralValueInUSD) = _getAccountInfo(user);

        if(totaleNRSMinted ==0){
            return type(uint256).max;
        }
        uint256 collateralAdjustedThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD)/100;
        return ((collateralAdjustedThreshold * 1e18 )/ totaleNRSMinted);        
    }

    function _calculateHealthFactor(uint256 totalMinted, uint256 collateralInUSD) internal pure returns(uint256){
        if(totalMinted == 0){
            return type(uint256).max;
        }
        uint256 collateralAdjustedThreshold = (collateralInUSD * LIQUIDATION_THRESHOLD)/100;
        return ((collateralAdjustedThreshold * 1e18 )/ totalMinted);      
    }
    

   

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // Check Health Factor
        // Revert IF they dont have enough

        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor<1){
            revert eNRS_Engine_BreaksHealthFactor(userHealthFactor);
        }


    }
     function _getAccountInfo(address user) private view returns (uint256 totaleNRSMinted, uint256 collateralValueInUSD) {
        totaleNRSMinted = s_eNRSMinted[user];
        collateralValueInUSD = getAccountCollateralValue(user);
    }

    // Public and external View Functions

    function getTokenAmountFromUsd(address token, uint256 USDAmountinWei)public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return (USDAmountinWei)*1e18 /(uint256(price)*1e10);
        }



    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUSD) {
        for (uint256 i = 0; i <= s_CollateralTokens.length; i++) {
            address token = s_CollateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUSD += getNRSValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getNRSValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * 1e10 * 133) * amount) / 1e18; // Additional Fee Precision * Precision
    }

    function gethealthFactor(address user) private view returns (uint256){
        uint256 healthFactor = _healthFactor(user);
        return healthFactor;
    }
    function calculateHealthFactor(uint256 totalMinted, uint256 collateralInUSD) external pure returns(uint256){
        return _calculateHealthFactor(totalMinted,collateralInUSD);
    }

    // function totalSupply() public view returns(uint256){
    //     return s_eNRSMinted;
    // }
    function getCollateralTokens() external view returns(address[] memory){
        return s_CollateralTokens;
    }

    function getCollateralBalance(address user, address token) external view returns(uint256){
        return s_collateralDeposited[user][token];
    }
    function getAccountInfo(address user) public view returns(uint256 totaleNRSMinted, uint256 collateralValueInUSD){
        ( totaleNRSMinted,  collateralValueInUSD) =_getAccountInfo(user);
    }
}